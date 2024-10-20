---@param context                       t.ghc.ux.IThemeContext
---@return ghc.ux.theme.integration.tabline.hlgroups
local function gen_hlgroup_map(context)
  local mode = context.scheme.mode ---@type t.eve.e.ThemeMode
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette
  local t = context.transparency ---@type boolean
  local bg_tabline = c.bg2

  ---@class ghc.ux.theme.integration.tabline.hlgroups : table<string, t.fml.ux.theme.IHlgroup>
  local hlgroup_map = {
    f_tl_bg = { fg = t and "none" or bg_tabline, bg = t and "none" or bg_tabline },
    f_tl_buf_item = { fg = c.grey, bg = t and "none" or c.bg1 },
    f_tl_buf_item_cur = { fg = c.fg0, bg = t and "none" or c.bg1 },
    f_tl_buf_left_pad = { fg = c.grey, bg = t and "none" or c.bg1 },
    f_tl_buf_left_pad_cur = { fg = c.blue, bg = t and "none" or c.bg1 },
    f_tl_buf_mod = { fg = c.red, bg = t and "none" or c.bg1 },
    f_tl_buf_mod_cur = { fg = c.green, bg = t and "none" or c.bg1 },
    f_tl_buf_title = { fg = c.grey, bg = t and "none" or c.bg1 },
    f_tl_buf_title_cur = { fg = c.fg0, bg = t and "none" or c.bg1 },
    f_tl_cwd = { fg = c.bg0_s, bg = c.green, bold = true },
    f_tl_devmode = { fg = c.bg0_s, bg = c.orange, bold = true },
    f_tl_sidebar_blank = { fg = c.fg0, bg = t and "none" or c.bg1 },
    f_tl_sidebar_text = { fg = c.blue, bg = t and "none" or c.bg1 },
    f_tl_sidebar_split = { fg = c.fg3, bg = t and "none" or c.bg1 },
    f_tl_tab_add = { fg = c.fg0, bg = c.bg3 },
    f_tl_tab_item = { fg = c.fg0, bg = c.bg1 },
    f_tl_tab_item_cur = { fg = c.red },
    f_tl_tab_toggle = { fg = c.bg0_s, bg = c.blue },
  }
  return hlgroup_map
end

return gen_hlgroup_map
