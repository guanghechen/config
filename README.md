# Bash Configuration

XDG-compliant bash config with modular structure and cross-platform support.

## Setup

```bash
./setup.bash
```

This will configure `~/.bash_profile`, `~/.bashrc`, and create `local/env.bash`.

## Structure

```
~/.config/bash/
├── config.bash               # Shared bootstrap and module load order
├── profile.bash              # Login compatibility entry
├── bashrc.bash               # Interactive compatibility entry
├── conf/
│   ├── app.bash              # App environment, paths and interactive hooks
│   ├── alias.bash            # Common aliases
│   ├── keymap.bash           # Readline bindings
│   └── platform/{osx,wsl,nix}/config.bash
├── functions/                # Shell functions (one per file)
├── completions/              # Custom completions
├── local/                    # Local config (git-ignored)
│   └── env.bash              # Sensitive env vars (API keys)
└── samples/                  # Templates for local/
```

## Startup

Like the Fish configuration, `config.bash` owns the load order:

1. Bootstrap environment, platform detection, preferences and base paths.
2. Local overrides from `local/env.bash`.
3. `conf/platform/$GHC_ENV_PLATFORM/config.bash`.
4. `conf/app.bash`, including Neovim selection and editor variables.
5. Interactive aliases, Readline bindings, functions and completions.

Both login and non-login interactive shells use this configuration. Non-interactive
login shells receive environment and PATH settings without prompt hooks, aliases,
Readline bindings or completions. Ordinary non-interactive shells are unchanged.

The existing `profile.bash` and `bashrc.bash` entry points load the configuration
once per shell; existing installations do not need to rerun setup. `sss` reloads
`config.bash` explicitly. App hooks and system completion initialize once per shell,
while environment, aliases, functions and custom completion definitions reload.

Preferences and local overrides are resolved before selecting applications.
Bash keeps its `nightly` Neovim and `stable` tmux defaults. The selected nightly
Neovim takes precedence in PATH, including when its path was already present.
PATH updates preserve paths containing spaces and avoid inserting duplicates.

## Conventions

- **Naming**: Functions use `ghc-*` prefix, files match function names
- **Extensions**: All files use `.bash`
- **Platform**: Auto-detected via `$GHC_ENV_PLATFORM` (osx/wsl/nix)

## Dependencies

Optional tools (gracefully skipped if missing):

starship, zoxide, fnm, fzf, fd, bat, lsd, delta

## Validation

```bash
python3 tests/startup.py
```

The tests use a temporary home, an explicit copy of configuration modules and
stub app hooks. They never copy or load the real `local/` directory. Set
`BASH_TEST_BIN` to test a different Bash executable.
