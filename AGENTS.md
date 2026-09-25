# Agent instructions

This is the PowerShell counterpart of `../fish` and `../bash`. See [README.md](README.md) for startup behavior.

- Keep shared variable names, helpers and local configuration conventions aligned across shells.
- Define overridable defaults in `profile.ps1` under `## local`, preserving inherited Windows defaults. Load local overrides before deriving values in `env.ps1`.
- Keep environment persistence in Windows setup; profile environment assignments are process-local.
- Do not read or copy `local/`; it may contain credentials.
- Validate scripts with the PowerShell parser and isolated fixtures when available. Do not load real profiles or change persistent user settings during validation.
