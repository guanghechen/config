---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return ghc.ui.theme.integration.tabline.hlgroups
local function gen_hlgroup_map(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors
  local t = params.transparency ---@type boolean

  ---@class ghc.ui.theme.integration.tabline.hlgroups : table<string, fml.types.ui.theme.IHlgroup>
  local hlgroup_map = {
    f_tl_bg = { fg = t and "none" or c.bg_statusline, bg = t and "none" or c.bg_statusline },
    f_tl_buf_item = { fg = c.light_grey, bg = t and "none" or c.black2 },
    f_tl_buf_item_cur = { fg = c.white, bg = t and "none" or c.black },
    f_tl_buf_left_pad = { fg = c.grey, bg = t and "none" or c.black2 },
    f_tl_buf_left_pad_cur = { fg = c.blue, bg = t and "none" or c.black },
    f_tl_buf_mod = { fg = c.red, bg = t and "none" or c.black2 },
    f_tl_buf_mod_cur = { fg = c.green, bg = t and "none" or c.black },
    f_tl_buf_title = { fg = c.light_grey, bg = t and "none" or c.black2 },
    f_tl_buf_title_cur = { fg = c.white, bg = t and "none" or c.black },
    f_tl_cwd = { fg = c.white_fg, bg = c.pink_bg },
    f_tl_neotree_blank = { fg = c.white, bg = t and "none" or c.black2 },
    f_tl_neotree_text = { fg = c.blue, bg = t and "none" or c.black2 },
    f_tl_neotree_split = { fg = c.line, bg = t and "none" or c.black2 },
    f_tl_search_blank = { fg = c.white, bg = t and "none" or c.black2 },
    f_tl_search_text = { fg = c.blue, bg = t and "none" or c.black2 },
    f_tl_search_split = { fg = c.line, bg = t and "none" or c.black2 },
    f_tl_tab_add = { fg = c.white, bg = c.one_bg2 },
    f_tl_tab_item = { fg = c.white, bg = c.black2 },
    f_tl_tab_item_cur = { fg = c.red },
    f_tl_tab_toggle = { fg = c.black, bg = c.blue },
  }
  return hlgroup_map
end

return gen_hlgroup_map
