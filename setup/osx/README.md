# macOS Setup

## System Settings

### General

- **Battery**
  - `Charging` -> `Charge Limit`: set to `80%`

- **Desktop & Dock**
  - Enable `Automatically hide and show the Dock`
  - Under `Mission Control`:
    - Disable `Automatically rearrange Spaces based on most recent use`
    - Enable `When switching to an application, switch to a Space with open windows for the application`
    - Enable `Group windows by application`
    - Enable `Displays have separate Spaces`
    - Enable `Drag windows to top of screen to enter Mission Control`

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

## FAQ

### Karabiner-Elements does not work

1. Open `System Settings` -> `General` -> `Login Items & Extensions`, then make sure both Karabiner-related items are enabled.
2. Karabiner-Elements also needs `Accessibility Access` and `Driver Extension` permissions. When the permission dialog appears, click `Open System Settings` and enable the requested permissions from the redirected settings page.
3. The Windows App bundle item uses this `Bundle Identifier`: `com.microsoft.rdc.macos`.
4. Use separate Karabiner-Elements profiles for different key mappings. This makes it possible to switch to a dedicated mapping when working inside a remote Windows session.
