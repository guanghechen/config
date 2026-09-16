# Ghostty background and theme state

[Architecture](../arch.md) · [Theme system](theme.md)

[shader.mjs](../../asset/theme/template/ghostty/shader.mjs) owns background
selection and persistence. The adjacent
[meta.mjs](../../asset/theme/template/ghostty/meta.mjs) calls it during theme
prepare/apply; [cli/ghostty-shader.mjs](../../cli/ghostty-shader.mjs) provides
selection, cycling, and listing for shell wrappers.

## Configuration ownership

Paths below are relative to `~/.config/ghostty`.

| File                | Responsibility                                                                    |
| ------------------- | --------------------------------------------------------------------------------- |
| `config`            | Permanent image fit, position, opacity, repetition, window/cell opacity, and blur |
| `local/theme.conf`  | Generated colors for the selected scheme                                          |
| `local/appearance`  | Current `dark` or `light` appearance                                              |
| `local/shader.conf` | Active image path and optional background shader; sole source of selection        |
| `shader.conf`       | Separately configured cursor shader                                               |

The writer never edits the main `config`. Changing a theme or shader only
changes selection-related files; permanent presentation settings apply in all
appearances and modes.

## Background selection

| Appearance | Selection    | `local/shader.conf` output                                           |
| ---------- | ------------ | -------------------------------------------------------------------- |
| Dark       | `off`        | `background-image` points to `asset/wallpaper/Flowerlit-Prayers.png` |
| Light      | `off`        | Empty `background-image` clears the image                            |
| Either     | Named shader | Clear the image and select `../shaders/<appearance>/<name>.glsl`     |

The image path is resolved from this repository's asset directory. Theme
switches retain the shader name and change its appearance directory. Both
appearances share the same cycling order. Here, `off` disables the background
shader; it does not disable the dark wallpaper or the cursor shader.

Wallpaper rendering uses Ghostty's native image support. Cell opacity lets
explicit TUI backgrounds reveal the image without per-application hooks or a
wallpaper shader. Image opacity controls blending with the theme background;
window opacity is applied afterward. Selected and reverse-video cells retain
Ghostty's opaque treatment. The actual numeric settings live in `config`.

## State and recovery

All background-state writes share a lock and rollback journal. Theme apply
commits the theme, appearance, and active background config together. Prepare
validates the selected image or shader without applying a new theme; recovery
of an interrupted transaction can run before validation.

Normal operations read only `local/shader.conf`, defaulting to `off` when it is
missing. The file must contain one of the current selection forms above.
Retired name files and per-appearance preferences are neither read nor deleted;
flat shader paths, light-name aliases, and presentation settings in the local
file are no longer migrated.

Recovery accepts version 4 journals targeting the current `theme`, `active`,
and `appearance` files. The complete journal is validated before any snapshot
is restored. Unsupported versions, retired targets, and malformed journals are
left in place and reported without partially restoring files.

## Reload and validation

The persistence module sends no reload signals. The shader CLI and theme
adapter signal Ghostty with `SIGUSR2` after saving. Neither restarts the app.
Ghostty documents macOS window-opacity changes as requiring a restart and
disables window transparency in native fullscreen.

[cli/ghostty-shader.test.mjs](../../cli/ghostty-shader.test.mjs) tests selection,
appearance changes, cross-process serialization, and rollback in temporary
directories. Config
parsing can be checked with `ghostty +validate-config`; visual confirmation
still requires the running application to load the files.
