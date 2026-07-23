# VS Code Assets

## Cross-platform keybinding parity

- Treat `keybinding/osx` and `keybinding/win` as one logical configuration: macOS `Cmd` maps to Windows `Alt`.
- Changes to positive keybindings must update both platforms together and preserve equivalent `command`, `when`, `args`, and effective precedence.
- Platform-specific differences are allowed only when required by platform behavior or defaults, such as clipboard commands and `unbind` inventories; keep the intent equivalent and state the reason during review.
- `keybindings.json` is generated with all `unbind` entries first, followed by a stable natural-key sort of `customize + rebind`. Edit the source files, regenerate it, and never maintain the generated file independently.
- For equal keys, order positive bindings from low to high runtime priority: unconditional fallback first, contextual bindings next, and terminal passthrough from `rebind` last. VS Code resolves equal-weight matches from the end of the file.
- Verify JSON parsing, generated composition, cross-platform semantic parity, and precedence-sensitive bindings.
