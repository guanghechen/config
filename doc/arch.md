# Architecture Documentation

## Overview

This repository (`guanghechen/config`) manages personal configuration files and setup scripts for multiple platforms (Linux/WSL, macOS, Windows).

## Directory Structure

```
.
├── asset/                    # Static assets
│   ├── app/                  # App-specific generated configs
│   ├── theme/                # Theme definitions
│   │   ├── app/              # Per-app theme templates
│   │   └── scheme/           # Color scheme JSON files
│   └── wallpaper/            # Wallpaper assets
├── cli/                      # CLI entry points
│   ├── setting.mjs           # Setting management CLI
│   ├── theme.mjs             # Theme application CLI
│   └── ...
├── config/                   # Static config templates
│   └── theme/app/            # Handlebars templates for themed configs
├── doc/                      # Documentation
├── env/                      # Environment configs (generated)
│   ├── env.mjs               # Path constants and platform detection
│   ├── setting.mjs           # Setting class
│   ├── setting.bash           # Settings for Bash (export KEY=value)
│   ├── setting.ps1           # Settings for PowerShell ($env:KEY = value)
│   └── repo.json             # Repository definitions
├── setup/                    # Platform-specific setup scripts
│   ├── nix/                  # Linux/WSL setup
│   │   ├── app/              # App installation scripts
│   │   ├── bot/              # Bootstrap scripts
│   │   │   └── env.bash        # PATH and environment bootstrap
│   │   └── env/              # Environment setup (node, rust, etc.)
│   ├── nix-remote/           # Remote Linux setup
│   ├── osx/                  # macOS setup
│   └── win/                  # Windows setup (PowerShell)
└── src/                      # Source modules
    └── stl/src/              # Standard library
        ├── commander.mjs     # CLI argument parser
        ├── env.mjs           # .env parser/serializer
        └── reporter.mjs      # Console output utilities
```

## Setting System

### Data Flow

```
┌───────────────────────────────────────────────────────┐
│                   cli/setting.mjs                     │
│                  (CLI entry point)                    │
└─────────────────────────┬─────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────┐
│                   src/setting.mjs                     │
│                   (Setting class)                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │
│  │   load()    │ │   save()    │ │  get/set()  │      │
│  │  parse env  │ │ write 2 fmt │ │             │      │
│  └─────────────┘ └─────────────┘ └─────────────┘      │
└─────────────────────────┬─────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────┐
│                 src/stl/src/env.mjs                   │
│  ┌────────────┐ ┌──────────────┐ ┌──────────────┐     │
│  │  parse()   │ │ stringify()  │ │stringifyPs1()│     │
│  └────────────┘ └──────────────┘ └──────────────┘     │
└─────────────────────────┬─────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────┐
│                        env/                           │
│      ┌──────────────┐         ┌──────────────┐        │
│      │ setting.bash │         │ setting.ps1  │        │
│      │    (bash)    │         │    (pwsh)    │        │
│      └──────┬───────┘         └───────┬──────┘        │
└─────────────┼─────────────────────────┼───────────────┘
              │                         │
              ▼                         ▼
       setup/nix/*.bash          setup/win/*.ps1
```

### Environment Variables

All environment variables follow the naming convention `GHC_*` (guanghechen):

| Variable               | Type                                     | Description               |
|------------------------|------------------------------------------|---------------------------|
| `GHC_EDITION`          | `nix` \| `nix-remote` \| `osx` \| `win`  | Platform edition          |
| `GHC_THEME`            | string                                   | Current theme name        |
| `GHC_APP_EDITION_NODE` | number                                   | Preferred Node.js version |
| `GHC_APP_EDITION_NVIM` | `latest` \| `nightly` \| `manual`        | Neovim edition            |
| `GHC_APP_EDITION_TMUX` | `latest` \| `nightly` \| `manual`        | Tmux edition              |
| `GHC_APP_PYTHON_ENV`   | string                                   | Python conda env name     |

### CLI Usage

```bash
# Print all settings
node cli/setting.mjs --print

# Set edition
node cli/setting.mjs --set-edition nix

# Set theme
node cli/setting.mjs --set-theme catppuccin-mocha

# Print specific value
node cli/setting.mjs --print-edition
node cli/setting.mjs --print-theme
node cli/setting.mjs --print-node-edition
node cli/setting.mjs --print-python-env
```

### Shell Integration

**Bash/Zsh:**
```bash
source "$HOME/.config/guanghechen/env/setting.bash"
echo $GHC_THEME
```

**PowerShell:**
```powershell
. "$env:XDG_CONFIG_HOME\guanghechen\env\setting.ps1"
echo $env:GHC_THEME
```

## Theme System

### Data Flow

```
┌───────────────────────────────────────────────────────┐
│                    cli/theme.mjs                      │
│                  (CLI entry point)                    │
└─────────────────────────┬─────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────┐
│                    src/theme.mjs                      │
│        ┌─────────────┐   ┌─────────────┐              │
│        │   apply()   │   │  generate() │              │
│        └─────────────┘   └─────────────┘              │
└─────────────────────────┬─────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│   scheme/   │   │    app/     │   │  template   │
│   *.json    │   │   *.hbs     │   │   render    │
└─────────────┘   └─────────────┘   └─────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────┐
│                Generated config files                 │
│    (alacritty, ghostty, tmux, nvim, vscode, etc.)     │
└───────────────────────────────────────────────────────┘
```

### Theme Templates

Templates use Handlebars syntax with color scheme variables:

```hbs
# Example: config/theme/app/alacritty.hbs
[colors.primary]
background = "{{background}}"
foreground = "{{foreground}}"

[colors.normal]
black = "{{black}}"
red = "{{red}}"
```

### Color Scheme Format

```json
{
  "background": "#1e1e2e",
  "foreground": "#cdd6f4",
  "black": "#45475a",
  "red": "#f38ba8",
  "green": "#a6e3a1",
  "yellow": "#f9e2af",
  "blue": "#89b4fa",
  "magenta": "#f5c2e7",
  "cyan": "#94e2d5",
  "white": "#bac2de"
}
```

## Setup Scripts

### Bootstrap Flow (Linux/WSL)

```
setup/nix/setup.bash
    │
    ├── apt update & install packages
    │
    ├── git clone/pull this repo
    │
    ├── source env/setting.bash (defaults, checked in)
    │
    ├── bot/config.bash (symlinks, profile)
    ├── bot/font-maple.bash (font installation)
    ├── bot/homebrew.bash (linuxbrew)
    ├── bot/fish.bash (fish shell)
    │
    ├── env/rust.bash (rustup)
    ├── env/miniforge.bash (conda)
    ├── env/bun.bash
    ├── env/node.bash (fnm + node)
    ├── env/pnpm.bash
    │
    ├── node cli/setting.mjs --set-edition nix
    │   └── generates env/setting.local.{bash,ps1}
    │
    ├── app/newsboat.bash
    ├── app/nvim.bash
    ├── app/tmux.bash
    ├── app/vscode.bash
    │
    └── node cli/theme.mjs apply
```

### Environment Bootstrap (setup/nix/bot/env.bash)

The `setup/nix/bot/env.bash` script is sourced by most setup scripts to ensure PATH and environment variables are properly configured:

```bash
source "$HOME/.config/guanghechen/env/setting.bash"

# Homebrew
export HOME_HOMEBREW=/home/linuxbrew/.linuxbrew
export PATH=$PATH:"$HOME_HOMEBREW/bin"

# Cargo
export PATH="$HOME/.cargo/bin:$PATH"

# fnm (Node version manager)
eval "$(fnm env --use-on-cd)"

# Miniforge (Conda)
eval "$("$HOME/.app/miniforge3/bin/conda" shell.bash hook)"
```

## Module Imports

The project uses Node.js subpath imports defined in `package.json`:

```json
{
  "imports": {
    "#env": "./src/env.mjs",
    "#setting": "./src/setting.mjs",
    "#stl/*": "./src/stl/src/*.mjs"
  }
}
```

Usage:
```javascript
import { PLATFORM, XDG_CONFIG_NODE_SETTING } from '#env'
import { Setting } from '#setting'
import { parse, stringify } from '#stl/env'
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'
```

## Design Principles

1. **Multi-shell support**: Generate configs for bash and PowerShell simultaneously
2. **Platform detection**: Auto-detect platform (nix, wsl, osx, win) and adjust defaults
3. **Single source of truth**: CLI manages settings, shells only source generated files
4. **No runtime Node.js dependency**: Shell scripts source static files, no `node` calls at startup
5. **Strict key validation**: Environment variable keys must match `[A-Z][A-Z0-9_]*`
6. **Idempotent setup**: Scripts can be re-run safely to update configurations
