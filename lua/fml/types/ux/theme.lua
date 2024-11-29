---@class fml.t.ux.IThemeContext
---@field public theme                  string
---@field public scheme                 eve.t.collection.theme.IScheme
---@field public transparency           boolean

---@class fml.t.ux.theme.IApp
---@field public get_filepaths          fun(context: fml.t.ux.IThemeContext): string[]
---@field public gen_theme              fun(context: fml.t.ux.IThemeContext): string
---@field public after_written          ?fun(context: fml.t.ux.IThemeContext): nil

---@alias fml.e.ux.theme.HighlightIntegration
---|"basic"
---|"statusline"
---|"tabline"
---|"winline"
---
---|"widget"
---|"treesitter"
---|"plugin"
