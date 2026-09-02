# VSC Theme References

The `vsc.hbs` family targets VS Code Dark Modern and Light Modern. References are selected in this
order: maintained app-specific port, official app theme contract combined with the upstream VS Code
theme, then an adjacent repository template when the app is private or has no public theme contract.

Implementation policy: every `vsc.hbs` owns its colors through `vsc.*` expressions. Except for Bat
and Codex, those expressions currently render identically to the adjacent `default.hbs`; this keeps
the present decisions stable while allowing later per-app refinement. The app-specific links below
are retained for audit.

The canonical VS Code sources shared by the mappings are:

Local source baseline: `/home/alice/sourcecodes/github/microsoft/vscode` at
`fb4a02b3e41d0d7c43d4908cca03b6eba9722e3f`.

- [Dark Modern](https://github.com/microsoft/vscode/blob/main/extensions/theme-defaults/themes/dark_modern.json)
  and [Light Modern](https://github.com/microsoft/vscode/blob/main/extensions/theme-defaults/themes/light_modern.json)
  for workbench roles.
- [Dark (Visual Studio)](https://github.com/microsoft/vscode/blob/main/extensions/theme-defaults/themes/dark_vs.json)
  and [Light (Visual Studio)](https://github.com/microsoft/vscode/blob/main/extensions/theme-defaults/themes/light_vs.json)
  for TextMate scopes.
- [VS Code terminal color registry](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/contrib/terminal/common/terminalColorRegistry.ts)
  for dark and light ANSI palettes.

| App | Primary app-specific reference | Reference use |
| --- | --- | --- |
| Alacritty | [alacritty-theme: vscode.toml](https://github.com/alacritty/alacritty-theme/blob/master/themes/vscode.toml) | Audit only; template mirrors default. |
| Bat | [Bat custom theme contract](https://github.com/sharkdp/bat#adding-new-themes) | Convert the official VS Code TextMate scopes to `.tmTheme`. |
| Btop | [Btop theme contract](https://github.com/aristocratos/btop/blob/main/src/btop_theme.cpp) | Audit only; template mirrors default. |
| Codex | [OpenAI configuration reference](https://developers.openai.com/codex/config-reference/) | Use official VS Code TextMate scopes for `tui.theme`; retain Codex-only status-line scopes. |
| Fzf | [Fzf color-role reference](https://github.com/junegunn/fzf/blob/master/man/man1/fzf.1) | Audit only; template mirrors default. |
| Gemini | [Gemini CLI custom theme contract](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/themes.md) | Audit only; template mirrors default. |
| Ghostty | [Dark+ Ghostty port](https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/ghostty/Dark%2B) | Audit only; template mirrors default. |
| Git Delta | [Delta custom themes](https://github.com/dandavison/delta/blob/main/manual/src/custom-themes.md) | Audit only; template mirrors default. |
| Herdr | [Herdr theme contract](https://github.com/herdrdev/herdr/blob/master/src/config/theme.rs) | Audit only; template mirrors default. |
| Kitty | [kitty-themes: VSCode Dark](https://github.com/kovidgoyal/kitty-themes/blob/master/themes/VSCode_Dark.conf) | Audit only; template mirrors default. |
| Lazygit | [Lazygit theme contract](https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md#color-attributes) | Audit only; template mirrors default. |
| Newsboat | [Newsboat colorschemes](https://github.com/newsboat/newsboat/tree/master/contrib/colorschemes) | Audit only; template mirrors default. |
| OpenCode | [VS Code Modern port](https://github.com/regen45t/opencode-vscode-themes/blob/main/vscode-modern.json) and [current theme contract](https://github.com/sst/opencode/blob/dev/packages/tui/src/theme/index.ts) | Audit only; template mirrors default. |
| Tmux | [tmux-dark-plus-theme](https://github.com/khanghh/tmux-dark-plus-theme) | Audit only; template mirrors default. |
| WezTerm | [Dark+ WezTerm port](https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/wezterm/Dark%2B.toml) | Audit only; template mirrors default. |
| Windows Terminal | [Dark+ Windows Terminal port](https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/windowsterminal/Dark%2B.json) | Audit only; template mirrors default. |
| Yazi | [vscode.yazi Dark/Light Modern](https://github.com/956MB/vscode.yazi) and [current schema](https://yazi-rs.github.io/schemas/theme.json) | Audit only; template mirrors default. |
| Yui | [Local Yui theme contract](../asset/theme/template/yui/default.hbs) | Audit only; template mirrors default. |

The reference ports are not copied into non-specialized templates. Their current output follows the
default mapping, while future VSC tuning stays local to each app template.
