# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

XDG-compliant bash configuration (`~/.config/bash/`) with modular structure and cross-platform support (osx/wsl/nix).

## Key Commands

```bash
./setup.bash          # Configure ~/.bash_profile and ~/.bashrc (idempotent)
shellcheck *.bash     # Lint bash scripts
```

**setup.bash is idempotent**: Running it multiple times produces the same result as running once. It uses marker comments (`# >>> bash-config >>>`) to detect existing configuration.

## Architecture

**Entry points** (bootstrapped by setup.bash):
- `~/.bash_profile` → sources `profile.bash` (login shell: env vars, PATH)
- `~/.bashrc` → sources `bashrc.bash` (interactive shell: alias, prompt, functions)

**Load order in bashrc.bash**:
1. `conf/app.bash` - App initialization (starship, zoxide, fnm)
2. `conf/alias.bash` - Alias definitions
3. `conf/keymap.bash` - Readline key bindings
4. `platform/$GHC_ENV_PLATFORM/bashrc.bash` - Platform-specific config
5. `functions/*.bash` - All function files (loop)
6. `completions/*.bash` - All completion files (loop)

**Platform detection**: `$GHC_ENV_PLATFORM` is set to `osx`, `wsl`, or `nix` based on runtime detection.

## Conventions

- **Function naming**: `ghc-*` prefix (e.g., `ghc-proxy`, `ghc-theme`)
- **File naming**: Match function name (e.g., `ghc-proxy.bash` defines `ghc-proxy()`)
- **Private helpers**: `_ghc_*` prefix (e.g., `_ghc_readline_context`)
- **Completions**: Same name as function (e.g., `ghc-theme.bash` completion for `ghc-theme`)
- **Extensions**: Always `.bash`, never `.sh`

## Sensitive Files

`local/env.bash` contains API keys and is git-ignored. Template at `samples/env.bash`.
