---@class t.ghc.ux.IThemeContext
---@field public theme                  string
---@field public scheme                 t.fml.ux.theme.IScheme
---@field public transparency           boolean

---@class t.ghc.ux.theme.IApp
---@field public get_filepaths          fun(context: t.ghc.ux.IThemeContext): string[]
---@field public gen_theme              fun(context: t.ghc.ux.IThemeContext): string
---@field public after_written          ?fun(context: t.ghc.ux.IThemeContext): nil

---@alias t.ghc.e.ux.theme.App
---|"alacritty"
---|"fish"
---|"lazygit"
---|"tmux"
---|"windows_terminal"

---@alias t.ghc.e.ux.theme.HighlightIntegration
---|"basic"
---|"statusline"
---|"tabline"
---|"winline"
---
---|"widget"
---|"treesitter"
---|"plugin"
