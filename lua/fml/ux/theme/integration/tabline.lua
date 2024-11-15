---@param context                       t.fml.ux.IThemeContext
---@return fml.ux.theme.integration.tabline.hlgroups
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.eve.collection.theme.IPalette
  local t = context.transparency ---@type boolean
  local bg_tabline = t and "none" or c.bg3 ---@type string
  local bg_buf_item = t and "none" or c.bg1 ---@type string
  local bg_buf_item_cur = t and "none" or c.bg0 ---@type string

  ---@class fml.ux.theme.integration.tabline.hlgroups : table<string, t.eve.collection.theme.IHlgroup>
  local hlgroup_map = {
    f_tl_bg = { fg = bg_tabline, bg = bg_tabline },
    f_tl_buf_item = { fg = c.bg4, bg = bg_buf_item },
    f_tl_buf_item_cur = { fg = c.bg4, bg = bg_buf_item_cur },
    f_tl_buf_indicator = { fg = c.bg4, bg = bg_buf_item },
    f_tl_buf_indicator_cur = { fg = c.blue, bg = bg_buf_item_cur, bold = true },
    f_tl_buf_mod = { fg = c.red, bg = bg_buf_item },
    f_tl_buf_mod_cur = { fg = c.green, bg = bg_buf_item_cur },
    f_tl_buf_title = { fg = c.fg3, bg = bg_buf_item },
    f_tl_buf_title_cur = { fg = c.fg2, bg = bg_buf_item_cur, bold = true },
    f_tl_devmode = { fg = c.bg0, bg = c.yellow, bold = true },
    f_tl_cwd = { fg = c.bg0, bg = c.green, bold = true },
    f_tl_sidebar_blank = { fg = c.fg1, bg = bg_buf_item },
    f_tl_sidebar_indicator = { fg = c.orange, bg = bg_buf_item },
    f_tl_sidebar_text = { fg = c.fg2, bg = bg_buf_item, bold = true },
    f_tl_sidebar_split = { fg = c.fg4, bg = bg_buf_item },
    f_tl_tab_add = { fg = c.fg1, bg = c.bg3 },
    f_tl_tab_item = { fg = c.fg1, bg = bg_tabline },
    f_tl_tab_item_cur = { fg = c.red, bg = bg_buf_item_cur },
    f_tl_tab_toggle = { fg = c.bg1, bg = c.green },
  }
  return hlgroup_map
end

return gen_hlgroup_map
