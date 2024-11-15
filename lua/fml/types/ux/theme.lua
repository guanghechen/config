---@class t.fml.ux.IThemeContext
---@field public theme                  string
---@field public scheme                 t.eve.collection.theme.IScheme
---@field public transparency           boolean

---@class t.fml.ux.theme.IApp
---@field public get_filepaths          fun(context: t.fml.ux.IThemeContext): string[]
---@field public gen_theme              fun(context: t.fml.ux.IThemeContext): string
---@field public after_written          ?fun(context: t.fml.ux.IThemeContext): nil

---@alias t.fml.e.ux.theme.HighlightIntegration
---|"basic"
---|"statusline"
---|"tabline"
---|"winline"
---
---|"widget"
---|"treesitter"
---|"plugin"
