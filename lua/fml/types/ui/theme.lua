---@class fml.types.ui.theme.IColors
---@field public base00                 string
---@field public base01                 string
---@field public base02                 string
---@field public base03                 string
---@field public base04                 string
---@field public base05                 string
---@field public base06                 string
---@field public base07                 string
---@field public base08                 string
---@field public base09                 string
---@field public base0A                 string
---@field public base0B                 string
---@field public base0C                 string
---@field public base0D                 string
---@field public base0E                 string
---@field public base0F                 string
---@field public baby_pink              string
---@field public black                  string
---@field public black2                 string
---@field public blue                   string
---@field public cyan                   string
---@field public darker_black           string
---@field public dark_purple            string
---@field public diff_add               string
---@field public diff_add_hl            string
---@field public diff_delete            string
---@field public diff_delete_hl         string
---@field public folder_bg              string
---@field public green                  string
---@field public grey                   string
---@field public grey_fg                string
---@field public grey_fg2               string
---@field public lavender               string
---@field public light_grey             string
---@field public lightbg                string
---@field public line                   string
---@field public nord_blue              string
---@field public one_bg                 string
---@field public one_bg2                string
---@field public one_bg3                string
---@field public orange                 string
---@field public pink                   string
---@field public pmenu_bg               string
---@field public purple                 string
---@field public red                    string
---@field public statusline_bg          string
---@field public sun                    string
---@field public tabline_bg             string
---@field public teal                   string
---@field public vibrant_green          string
---@field public white                  string
---@field public yellow                 string

---@class fml.types.ui.theme.IScheme
---@field public mode                   fml.enums.theme.Mode
---@field public colors                 fml.types.ui.theme.IColors

---@class fml.types.ui.theme.IHlgroup : vim.api.keyset.highlight

---@class fml.types.ui.theme.IApplyParams
---@field public scheme                 fml.types.ui.theme.IScheme
---@field public nsnr                   integer

---@class fml.types.ui.theme.ICompileParams
---@field public scheme                 fml.types.ui.theme.IScheme
---@field public filepath               string
---@field public nsnr                   integer

---@class fml.types.ui.ITheme
---@field public apply                  fun(self: fml.types.ui.ITheme, params: fml.types.ui.theme.IApplyParams): nil
---@field public compile                fun(self: fml.types.ui.ITheme, params: fml.types.ui.theme.ICompileParams): nil
---@field public register               fun(self: fml.types.ui.ITheme, hlname: string, hlgroup: fml.types.ui.theme.IHlgroup): fml.types.ui.ITheme
---@field public registers              fun(self: fml.types.ui.ITheme, hlgroup_map: table<string, fml.types.ui.theme.IHlgroup | nil>): fml.types.ui.ITheme
