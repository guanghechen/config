# Bash configuration

Bash counterpart of [`../fish`](../fish), sharing configuration conventions and helper names.

## Setup

```bash
./setup.bash
```

Registers the login and interactive entry points and creates `local/env.bash` if absent.

## Local configuration

Use `local/env.bash` for machine-specific settings. In `config.bash`, follow the same order as fish:

1. Define overridable defaults in `## local`.
2. Source `local/env.bash` after those defaults.
3. Compute derived values and apply fixed settings in subsequent sections.

To make a variable locally configurable, move its default before the `source` block. For example, define `KIT_COPILOT_URL` there and derive API endpoints afterward.

## Bash specifics

- `profile.bash` and `bashrc.bash` load configuration once per shell; `source ~/.config/bash/config.bash` or `sss` reloads it. App hooks and system completion initialize once.
- Non-interactive login shells receive environment and PATH settings; prompts, bindings, functions and completions are interactive-only.
- Bash explicitly sources function files; fish autoloads them. Neovim defaults to `nightly` here and `stable` in fish.
