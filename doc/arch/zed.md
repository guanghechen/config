# Zed theme adapter

[Architecture](../arch.md) · [Theme system](theme.md)

[asset/theme/template/zed](../../asset/theme/template/zed) generates a JSON
theme per scheme and selects it through a CLI-owned settings layer. The
adapter does not modify the user's `settings.json`.

## Paths and ownership

[meta.mjs](../../asset/theme/template/zed/meta.mjs) resolves Zed's native paths,
independently of this checkout's location:

- macOS: `~/.config/zed`.
- Linux/FreeBSD: choose `FLATPAK_XDG_CONFIG_HOME`, then `XDG_CONFIG_HOME`; use
  `~/.config` if the selected value is absent or relative. Append `zed`.
- Windows: `%APPDATA%/Zed`, with the standard roaming directory as fallback.

The adapter activates only when `settings.json` exists. Generated themes live
in `themes/<scheme>.json`. `global_settings.json` contains the generated header
and the selected full scheme name, for example `{"theme":"vsc-dark-modern"}`.
Both generated outputs are tracked by the Zed worktree.

Zed 1.19.2 reads this layer below `settings.json` and watches it for updates;
see [global settings paths](https://github.com/zed-industries/zed/blob/v1.19.2/crates/paths/src/paths.rs)
and [SettingsStore](https://github.com/zed-industries/zed/blob/v1.19.2/crates/settings/src/settings_store.rs).
An explicit user theme, including a theme-picker or settings-profile override,
takes precedence. Remove that override to follow the CLI-selected scheme and
its light/dark appearance.

## Publishing contract

Prepare rejects an existing `global_settings.json` without the generated
header. Personal settings belong in `settings.json`; the generated layer is
owned exclusively by the CLI.

Apply validates ownership again, publishes the theme file, then publishes its
selection. Each file is replaced atomically. Existing permissions are preserved
and new files respect umask. If the theme write fails, selection stays unchanged;
if the later selection write fails, an unused theme may remain. User saves,
comments, and settings symlinks are unaffected because the adapter never writes
`settings.json`.

Zed also watches the theme directory, so regenerating an already-selected theme
can update it without changing its name.

## Color mapping

`default.hbs` uses shared `unified` roles. Catppuccin, Gruvbox, Kanagawa,
Rosé Pine, Tokyo Night, and VSC each provide a complete family template.
Native palettes own terminal ANSI colors; UI and syntax retain the schemes'
readability adjustments. Zed-only colors stay in its templates.

The VSC template follows
[zed-vscode-modern-theme at 66495b4](https://github.com/fabrialberio/zed-vscode-modern-theme/tree/66495b44ace48282b1fb85ece9c53538bb5359eb).
Shared roles reference `vsc`; Zed-specific adjustments use local hex values.

Rendering validates JSON, the single theme's name and appearance, unresolved
expressions, and accent color format. Tests in
[cli/theme/zed.test.mjs](../../cli/theme/zed.test.mjs) cover mappings, ownership,
concurrent user saves, permissions, and publication failures.
