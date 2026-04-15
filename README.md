# [Project Name]

[One-line description]

## Setup

1. Install the Bitwarden CLI and authenticate:
   ```powershell
   npm install -g @bitwarden/cli
   bw login
   $env:BW_SESSION = (bw unlock --raw)
   ```
2. Populate `.env` from the vault:
   ```powershell
   ./scripts/setup-env.ps1
   ```
3. [Project-specific install/run steps]

## Documentation

- `CLAUDE.md` — conventions and standing instructions for CLI sessions
- `PROJECT_STATE.md` — session history and current status
- `docs/session-briefs/` — planning briefs from Code Companion
