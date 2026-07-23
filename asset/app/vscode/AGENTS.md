# VS Code Assets

## Cross-platform keybinding parity

- Treat `keybinding/osx` and `keybinding/win` as one logical configuration: macOS `Cmd` maps to Windows `Alt`.
- Changes to positive keybindings must update both platforms together and preserve equivalent `command`, `when`, `args`, and effective precedence.
- Platform-specific differences are allowed only when required by platform behavior or defaults, such as clipboard commands and `unbind` inventories; keep the intent equivalent and state the reason during review.
- `keybindings.json` is generated in `unbind + customize + rebind` order. Edit the source files, regenerate it, and never maintain the generated file independently.
- Verify JSON parsing, source/generated equality, cross-platform semantic parity, and precedence-sensitive bindings.
