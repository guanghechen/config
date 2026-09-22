# AGENTS.md

This file provides guidance to coding agents working in this repository.

## Overview

XDG-compliant bash configuration (`~/.config/bash/`) with modular structure and cross-platform support (osx/wsl/nix).

## Key Commands

```bash
./setup.bash          # Configure ~/.bash_profile and ~/.bashrc (idempotent)
shellcheck *.bash     # Lint bash scripts
python3 tests/startup.py # Isolated startup and PATH regression checks
```

**setup.bash is idempotent**: Running it multiple times produces the same result as running once. It uses marker comments (`# >>> bash-config >>>`) to detect existing configuration.

## Architecture

**Entry points** (bootstrapped by setup.bash):
- `~/.bash_profile` → `profile.bash` → `config.bash`
- `~/.bashrc` → `bashrc.bash` → `config.bash` (interactive shells only)

**Load order in config.bash**, following the Fish configuration:
1. Bootstrap environment, platform detection and preferences
2. `local/env.bash` - Optional local overrides
3. `conf/platform/$GHC_ENV_PLATFORM/config.bash` - Platform environment and interactive aliases
4. `conf/app.bash` - App environment, paths and interactive hooks
5. `conf/alias.bash` and `conf/keymap.bash` - Interactive aliases and Readline bindings
6. `functions/*.bash` - All function files (loop)
7. System bash-completion, then `completions/*.bash`

The compatibility entries load `config.bash` once per shell. Explicitly sourcing
`config.bash` (or using `sss`) reloads configuration, while app hooks and system
completion remain guarded against duplicate initialization. Non-interactive login
shells stop after app environment setup. WSL-specific functions live in
`conf/platform/wsl/fn/*.bash` and are loaded only in interactive WSL shells.

**Platform detection**: `$GHC_ENV_PLATFORM` is set to `osx`, `wsl`, or `nix` based on runtime detection.

## Conventions

- **Function naming**: `ghc-*` prefix (e.g., `ghc-proxy`, `ghc-theme`)
- **File naming**: Match function name (e.g., `ghc-proxy.bash` defines `ghc-proxy()`)
- **Private helpers**: `_ghc_*` prefix (e.g., `_ghc_readline_context`)
- **Completions**: Same name as function (e.g., `ghc-theme.bash` completion for `ghc-theme`)
- **Extensions**: Always `.bash`, never `.sh`

## Sensitive Files

`local/env.bash` contains API keys and is git-ignored. Template at `samples/env.bash`.
