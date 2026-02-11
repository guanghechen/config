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
├── profile.bash              # Login shell (env vars, PATH)
├── bashrc.bash               # Interactive shell (alias, prompt)
├── conf/                     # Modular config (app, alias, keymap)
├── functions/                # Shell functions (one per file)
├── completions/              # Custom completions
├── platform/{osx,wsl,nix}/   # Platform-specific config
├── local/                    # Local config (git-ignored)
│   └── env.bash              # Sensitive env vars (API keys)
└── samples/                  # Templates for local/
```

## Conventions

- **Naming**: Functions use `ghc-*` prefix, files match function names
- **Extensions**: All files use `.bash`
- **Platform**: Auto-detected via `$GHC_ENV_PLATFORM` (osx/wsl/nix)

## Dependencies

Optional tools (gracefully skipped if missing):

starship, zoxide, fnm, fzf, fd, bat, lsd, delta
