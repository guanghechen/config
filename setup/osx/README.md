# macOS Setup

## System Settings

### General

- **Battery**
  - `Charging` -> `Charge Limit`: set to `80%`

- **Desktop & Dock**
  - Enable `Automatically hide and show the Dock`

### Finder

- **Path bar**
  - `View` -> `Show Path Bar`
  - Shortcut: `Option + Command + P`

- **Status bar**
  - `View` -> `Show Status Bar`
  - Shortcut: `Command + /`

- **Filename extensions**
  - `Finder` -> `Settings` -> `Advanced`
  - Enable `Show all filename extensions`

- **Search scope**
  - `Finder` -> `Settings` -> `Advanced`
  - Set `When performing a search` to `Search the Current Folder`

- **Folder sorting**
  - `Finder` -> `Settings` -> `Advanced`
  - Enable `Keep folders on top: In windows when sorting by name`

- **Default view**
  - `View` -> `as List`
  - Shortcut: `Command + 2`
  - Then `View` -> `Show View Options` -> `Use as Defaults`

### Finder Hygiene

- **Avoid `.DS_Store` on shared volumes**
  - `defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true`
  - `defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true`
  - Restart Finder: `killall Finder`

- **Ignore `.DS_Store` in Git**
  - Add `.DS_Store` to `~/.gitignore_global`
  - Set `core.excludesfile` to `~/.gitignore_global`

- **Clean local `.DS_Store` files manually**
  - Run inside the target directory only:
    ```bash
    fd -H '^\.DS_Store$' . -x rm
    ```

## Keyboard Shortcuts

Open `System Settings` -> `Keyboard` -> `Keyboard Shortcuts`.

- **Keyboard**
  - Set `Move focus to next window` to `` Option + ` ``
  - Disable other shortcuts

- **Screenshots**
  - Disable all shortcuts

- **Function Keys**
  - Enable `Use F1, F2, etc. keys as standard function keys`

- **Modifier Keys**
  - `Globe` -> `Control`
  - `Control` -> `Globe`
