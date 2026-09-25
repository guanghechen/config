# PowerShell configuration

PowerShell counterpart of [`../fish`](../fish) and [`../bash`](../bash), sharing configuration conventions and helper names.

## Setup

The Windows setup in `../guanghechen/setup/win/` installs `profile.ps1` as the PowerShell profile and persists user environment defaults. Changes to `profile.ps1` require updating the installed copy.

## Local configuration

Use `local/env.ps1` for machine-specific settings. Keep this order:

1. Define overridable defaults under `## local` in `profile.ps1`, preserving inherited values.
2. Load `local/env.ps1` after those defaults.
3. Derive paths and API endpoints in `env.ps1`, then load app functions and completions.

To make a variable locally configurable, define its default before the local load. For example, the three API endpoints follow the final `KIT_COPILOT_URL`.

## PowerShell specifics

- Windows setup persists defaults; profile overrides and derived endpoints affect the current process and its children.
- Model IDs and FZF settings remain managed by Windows setup.
- Windows paths use `USERPROFILE`; no separate Windows username setting is needed.
