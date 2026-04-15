# [Project Name]

## Overview
[What this project does — fill in during first session]

## Tech Stack
[Fill in during first session]

## Notion Page
[Paste Notion page URL here so CLI knows where to write closeouts]

---

## Standing Conventions

### Session Closeout Protocol
- After every CLI session, write a brief closeout to the project's Notion page
- Always fetch the Notion page first before writing — never duplicate what's already there
- If Code Companion already logged context from the planning side, supplement — don't overwrite
- CLI logs implementation specifics (commits, files changed, what was built)

### Git Discipline
- Commit and push before ending any session
- Commit before switching machines

### Secrets
- Never write real API keys or secrets into files
- Use `scripts/setup-env.ps1` to populate `.env` from the Bitwarden vault
- `.env.template` maps variable names to vault paths — edit this when adding new keys
- `DATA_DIR` and other machine-local values go in `.env.local` (also gitignored)

### File Deletion Safety
- Any operation involving file deletion must explicitly list every file to delete
  AND explicitly list what must NOT be deleted. No blanket instructions.

### Session Briefs
- Session briefs live in `docs/session-briefs/` — check there for current session context
- `PROJECT_STATE.md` tracks session history and current status
