# Architecture Documentation

## Overview

This repository (`guanghechen/config`) manages personal configuration files and setup scripts for multiple platforms (Linux/WSL, macOS, Windows).

## Directory Structure

```
.
├── asset/                    # Static assets
│   ├── app/                  # App-specific generated configs
│   ├── theme/                # Theme definitions
│   │   ├── scheme/           # Color scheme JSON files
│   │   └── template/         # Per-app theme metadata and templates
│   │       └── {app}/        # meta.mjs, default.hbs, family.hbs
│   └── wallpaper/            # Wallpaper assets
├── cli/                      # CLI entry points
│   ├── setting.mjs           # Setting management CLI
│   ├── theme.mjs             # Theme application CLI
│   └── ...
├── doc/                      # Documentation
├── env/                      # Environment configs (generated)
│   ├── env.mjs               # Path constants and platform detection
│   ├── setting.mjs           # Setting class
│   ├── setting.bash           # Settings for Bash (export KEY=value)
│   └── setting.ps1           # Settings for PowerShell ($env:KEY = value)
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

# Set values
node cli/setting.mjs --set-node-edition 24
node cli/setting.mjs --set-nvim-edition manual
node cli/setting.mjs --set-python-env lemon
node cli/setting.mjs --set-theme catppuccin-mocha
node cli/setting.mjs --set-tmux-edition latest

# Print specific value
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
┌─────────────┐   ┌─────────────────┐   ┌─────────────┐
│   scheme/   │   │    template/    │   │  template   │
│   *.json    │   │ meta.mjs,*.hbs  │   │   render    │
└─────────────┘   └─────────────────┘   └─────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────┐
│                Generated config files                 │
│    (alacritty, ghostty, tmux, nvim, vscode, etc.)     │
└───────────────────────────────────────────────────────┘
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

### Ghostty Shader State

`asset/theme/template/ghostty/shader.mjs` owns Ghostty's shader catalog and
persistent state. The adjacent `meta.mjs` invokes it during theme prepare/apply;
`cli/ghostty-shader.mjs` is the command-line adapter used by the Fish and Bash
wrappers. Both paths share
one lock and transaction journal. Applying a theme restores the corresponding
`local/shader-dark.conf` or `local/shader-light.conf` into `local/shader.conf` together with
`local/theme.conf` and `local/appearance`; selecting a shader updates the current
appearance's saved selection and active file together. Ghostty reloads only the
active file. Both appearances expose the same shader names. Saved and active
configs use `../shaders/<dark|light>/name.glsl`. Legacy flat paths and the old `cubes-light`
and `inside-the-matrix-light` names normalize to this layout on the next write.
Old root-level `theme-dark.conf` and `theme-light.conf` take precedence over stale
local state during migration; the writer saves their selections locally and
deletes those root files in one transaction. Subsequent selections stay under
`local/`, including empty/off. A qualified path must match its saved appearance;
ambiguous legacy Neuro Noise selections use the appearance marker. Version 1
journals recover local saved files, version 2 journals recover old root configs,
and version 3 journals cover local state and retirement of the old root files.

### Theme Templates

Rosé Pine keeps its named swatches in `palette.rosepine`; `palette.unified`
provides custom readable foregrounds for app UI and syntax. Terminal ANSI slots
reference the original palette directly and follow the official Ghostty port:
green uses pine, blue uses foam, cyan uses rose; the six accent colors are shared
between normal and bright slots. Ordinary terminal text uses `unified.fg1`.
Dawn pairs ink-colored body text with deeper accents and Medium weight in
Windows Terminal; Main and Moon lift pine and secondary text where needed.
Use `fg1` on neutral selections and `bg0` on solid accent fills;
reserve `muted` for disabled elements. Diff backgrounds are separate from
foreground accents so inline changes remain readable.

Catppuccin follows the same separation: `palette.catppuccin` retains the official
swatches and terminal ANSI mapping, including Latte's reversed neutral slots.
`palette.unified` uses text for body copy, readable secondary text, mauve for
purple, and separate pink accents. Latte uses ink-colored text and deeper app
accents; its neutral surfaces step from mantle through crust to surface0.
Active tmux sessions use blue and active windows use mauve, with a continuous
fill and base-colored text. Neutral selections retain the body foreground;
inline diffs use the body foreground over stronger red or green tints.

Kanagawa keeps the upstream named palette and the Wave, Dragon and Lotus ANSI
mappings from `kanagawa.nvim`. Readability adjustments live in `unified`: Wave
uses Fuji White body text and clearer muted text; Dragon keeps its neutral ink,
wood and green tones; Lotus pairs its paper background with deeper ink and
accents. Terminal named colors stay independent from these app accents.
Active tmux sessions use blue and active windows use sand gold, both with a
continuous fill and base-colored text. Neutral selections and inline diffs
retain the body foreground, including Neovim's native and custom diff groups.
Lotus uses Medium weight in Windows Terminal, matching the other light themes.

Tokyo Night preserves its named palette and official terminal mapping, including
the upstream HSLuv-generated bright ANSI swatches. App colors live in `unified`:
Night, Storm and Moon retain their blue-violet character with clearer secondary
text, while Day uses blue-gray ink and deeper accents. The Neovim family maps
consume these app colors for UI and syntax without modifying the stored palette.
Neutral selections and inline diffs carry readable foregrounds; tmux sessions
use blue and windows use violet. Day uses Medium weight in Windows Terminal.
Yazi progress labels inherit Gauge's foreground inversion on filled cells.

Each app directory contains validated metadata and Handlebars templates:

```js
import path from 'node:path'

import { XDG_CONFIG_HOME } from '#env'
import { touch } from '#util/path'

export default {
  location: path.join(XDG_CONFIG_HOME, 'alacritty'),
  active: { directory: '.' },
  themes: 'theme/',
  extname: '.toml',
  local: 'local/theme.toml',
  on_after_apply: async function (app, _scheme, reporter) {
    await touch(path.join(app.home, 'alacritty.toml'), reporter)
  },
}
```

Templates use color scheme variables:

```hbs
# Example: asset/theme/template/alacritty/default.hbs
[colors.primary]
background = "{{background}}"
foreground = "{{foreground}}"

[colors.normal]
black = "{{black}}"
red = "{{red}}"
```

## Setup Scripts

### Bootstrap Flow (Linux/WSL)

```
setup/nix/setup.bash
    ├── require sudo + apt [fatal]
    ├── apt update/upgrade + system packages [fatal]
    ├── clone or fast-forward this repo [fatal]
    ├── source bot/step.bash [fatal]
    ├── bootstrap
    │   ├── source bot/env.bash [fatal]
    │   └── bot/homebrew.bash [optional, conditional]
    ├── environment
    │   ├── env/rust.bash
    │   ├── env/miniforge.bash
    │   ├── env/bun.bash
    │   ├── bot/fish.bash
    │   ├── env/node.bash
    │   └── refresh bot/env.bash [fatal]
    ├── configuration
    │   ├── require cargo + install published kit-repo [fatal]
    │   ├── create/attach kit worktree [fatal]
    │   ├── kit repo set config.edition nix + kit repo sync [fatal]
    │   └── bot/config.bash [optional]
    ├── applications
    │   ├── app/newsboat.bash
    │   ├── app/nvim.bash
    │   ├── app/tmux.bash
    │   ├── app/windows-terminal.bash [WSL only]
    │   ├── bot/font-maple.bash
    │   ├── require node [fatal]
    │   └── node cli/theme.mjs apply
    └── ghc_step_summary
```

Fatal steps abort immediately. Optional leaf scripts run in isolated
`bash -e -o pipefail` processes; optional failures are collected and make
`ghc_step_summary` return non-zero.

`setup/nix/bot/step.bash` renders a flat output forest: composition roots pass
explicit section/step icons, and each step owns one rounded tree. Output is
color-preserving, normalized into indented lines, and separated from adjacent
steps by one blank line. Ordinary steps run in isolated shells; environment
refreshes run in place. The local-settings sync remains unwrapped because
`kit-repo` owns that output, while a non-zero status is still fatal.

### Bootstrap Flow (Windows)

```
setup/win/setup.ps1
    ├── require PowerShell 7.4+ + git + winget + cargo + rustc [fatal]
    ├── persist base environment + clone or fast-forward this repo [fatal]
    ├── source bot/step.ps1 [fatal]
    ├── bootstrap
    │   ├── load env/setting.ps1 [fatal]
    │   └── winget.ps1 [optional]
    ├── environment
    │   ├── env/miniforge.ps1
    │   ├── env/bun.ps1
    │   └── env/node.ps1
    ├── configuration
    │   ├── require cargo + install published kit-repo [fatal]
    │   ├── create/attach kit worktree [fatal]
    │   ├── kit repo set config.edition win + kit repo sync [fatal]
    │   ├── config.ps1
    │   └── env/codex.ps1
    ├── applications
    │   ├── app/newsboat.ps1
    │   ├── app/nvim.ps1
    │   ├── bot/font-maple.ps1
    │   ├── require node [fatal]
    │   └── theme.ps1
    └── Complete-GhcSetup
```

`setup/win/bot/step.ps1` implements the same forest and optional-failure
collection as the Bash helper. PowerShell and native-command errors are
terminating by default; required failures throw an exception carrying the
original exit code in `Exception.Data["ExitCode"]`, so an
`Invoke-Expression` caller keeps its PowerShell process. Output streams are
combined, color-preserved, and rendered beneath the step rail. Steps execute in
child scopes within the setup process, so process environment mutations
persist; scripts that require shell functions initialize them locally.
Expected non-zero probes opt out of native error promotion at their call site.
The entrypoint rejects PowerShell versions older than 7.4 before any mutation.
The `kit-repo` local-settings sync remains unwrapped and fatal. Environment
and application leaves, plus Codex and config setup, are optional and collected
in the final summary.

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
