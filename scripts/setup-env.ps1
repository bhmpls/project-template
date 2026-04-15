# setup-env.ps1
# Populates .env from Bitwarden vault using mappings in .env.template.
#
# Usage:
#   .\scripts\setup-env.ps1            # writes .env, refuses to overwrite existing
#   .\scripts\setup-env.ps1 -Force     # overwrites existing .env
#
# Prerequisites:
#   1. Bitwarden CLI installed:   npm install -g @bitwarden/cli
#   2. Logged in:                 bw login
#   3. Unlocked with session key exported:
#        $env:BW_SESSION = (bw unlock --raw)
#
# .env.template format:
#   KEY=bw://<folder-path>/<item-name>   -> pulled from vault (password field)
#   KEY=local://prompt                   -> prompted once, cached in .env.local
#   KEY=<literal>                        -> written as-is
#   # comments and blank lines ignored

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Fail($msg) {
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
}

# --- Preflight --------------------------------------------------------------

if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Fail "Bitwarden CLI not found. Install: npm install -g @bitwarden/cli"
}

if (-not $env:BW_SESSION) {
    Write-Host "BW_SESSION not set. Run:" -ForegroundColor Yellow
    Write-Host '  $env:BW_SESSION = (bw unlock --raw)' -ForegroundColor Yellow
    exit 1
}

$status = (bw status --session $env:BW_SESSION | ConvertFrom-Json).status
if ($status -ne 'unlocked') {
    Fail "Vault status is '$status'. Re-run: `$env:BW_SESSION = (bw unlock --raw)"
}

$projectRoot = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
$templatePath = Join-Path $projectRoot '.env.template'
$envPath      = Join-Path $projectRoot '.env'
$localPath    = Join-Path $projectRoot '.env.local'

if (-not (Test-Path $templatePath)) {
    Fail ".env.template not found at $templatePath"
}

if ((Test-Path $envPath) -and -not $Force) {
    Fail ".env already exists. Re-run with -Force to overwrite."
}

# --- Sync vault -------------------------------------------------------------

Write-Host "Syncing vault..." -ForegroundColor Cyan
bw sync --session $env:BW_SESSION | Out-Null

# --- Load folders and .env.local cache --------------------------------------

$folders = bw list folders --session $env:BW_SESSION | ConvertFrom-Json
$folderByName = @{}
foreach ($f in $folders) { $folderByName[$f.name] = $f.id }

$localCache = @{}
if (Test-Path $localPath) {
    foreach ($line in Get-Content $localPath) {
        if ($line -match '^\s*([^#=\s][^=]*)=(.*)$') {
            $localCache[$matches[1].Trim()] = $matches[2]
        }
    }
}

# Cache items-per-folder so we only hit `bw list items` once per folder
$itemsByFolderId = @{}
function Get-FolderItems($folderId) {
    if (-not $itemsByFolderId.ContainsKey($folderId)) {
        $itemsByFolderId[$folderId] = bw list items --folderid $folderId --session $env:BW_SESSION | ConvertFrom-Json
    }
    return $itemsByFolderId[$folderId]
}

# --- Parse template and resolve values --------------------------------------

$outputLines = @()
$populated = @()
$newLocals = @{}

foreach ($line in Get-Content $templatePath) {
    # Preserve blank lines and comments
    if ($line -match '^\s*$' -or $line -match '^\s*#') {
        $outputLines += $line
        continue
    }

    if ($line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
        $outputLines += $line
        continue
    }

    $key = $matches[1]
    $spec = $matches[2].Trim()

    if ($spec -like 'bw://*') {
        $path = $spec.Substring(5)
        $segments = $path -split '/'
        if ($segments.Count -lt 2) {
            Fail "Invalid bw:// spec for ${key}: '$spec' (need folder/item)"
        }
        $itemName = $segments[-1]
        $folderName = ($segments[0..($segments.Count - 2)]) -join '/'

        if (-not $folderByName.ContainsKey($folderName)) {
            Fail "Folder not found in vault: '$folderName' (for $key)"
        }
        $items = Get-FolderItems $folderByName[$folderName]
        $item = $items | Where-Object { $_.name -eq $itemName } | Select-Object -First 1
        if (-not $item) {
            Fail "Item '$itemName' not found in folder '$folderName' (for $key)"
        }

        $value = bw get password $item.id --session $env:BW_SESSION
        $outputLines += "$key=$value"
        $populated += "$key  <- bw://$folderName/$itemName"
    }
    elseif ($spec -eq 'local://prompt') {
        if ($localCache.ContainsKey($key)) {
            $value = $localCache[$key]
            $populated += "$key  <- .env.local (cached)"
        } else {
            $value = Read-Host "Enter value for $key (will be cached in .env.local)"
            $newLocals[$key] = $value
            $populated += "$key  <- prompted (cached to .env.local)"
        }
        $outputLines += "$key=$value"
    }
    else {
        # Literal value
        $outputLines += "$key=$spec"
        $populated += "$key  <- literal"
    }
}

# --- Write .env and update .env.local ---------------------------------------

Set-Content -Path $envPath -Value $outputLines -Encoding UTF8

if ($newLocals.Count -gt 0) {
    $localLines = @()
    if (Test-Path $localPath) { $localLines = Get-Content $localPath }
    foreach ($k in $newLocals.Keys) {
        $localLines += "$k=$($newLocals[$k])"
    }
    Set-Content -Path $localPath -Value $localLines -Encoding UTF8
}

# --- Summary ----------------------------------------------------------------

Write-Host ""
Write-Host "Wrote $envPath" -ForegroundColor Green
Write-Host "Populated:" -ForegroundColor Green
foreach ($p in $populated) { Write-Host "  $p" }
