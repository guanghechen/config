---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors
  local t = params.transparency ---@type boolean

  return {
    ---common
    f_transparent = { bg = "none" },

    ---diff
    f_diff_add_left = { bg = c.diff_del, fg = "none" },
    f_diff_add_right = { bg = c.diff_add, fg = "none" },
    f_diff_del_left = { bg = c.diff_del, fg = "none" },
    f_diff_del_right = { bg = c.diff_del, fg = "none" },
    f_diff_mod_left = { bg = c.diff_del, fg = "none" },
    f_diff_mod_right = { bg = c.diff_add, fg = "none" },
    f_diff_word_left = { bg = c.diff_del_word, fg = "none" },
    f_diff_word_right = { bg = c.diff_add_word, fg = "none" },

    ---statusline
    f_sl_bg = { fg = t and "none" or c.statusline_bg, bg = t and "none" or c.statusline_bg },
    f_sl_copilot_InProgress = { fg = c.cyan, bg = t and "none" or c.statusline_bg },
    f_sl_copilot_Normal = { fg = c.blue, bg = t and "none" or c.statusline_bg },
    f_sl_copilot_Warning = { fg = c.yellow, bg = t and "none" or c.statusline_bg },
    f_sl_diagnostics_error = { fg = c.red, bg = t and "none" or c.statusline_bg },
    f_sl_diagnostics_hint = { fg = c.purple, bg = t and "none" or c.statusline_bg },
    f_sl_diagnostics_info = { fg = c.green, bg = t and "none" or c.statusline_bg },
    f_sl_diagnostics_warn = { fg = c.yellow, bg = t and "none" or c.statusline_bg },
    f_sl_flag = { fg = c.white, bg = t and "none" or c.grey },
    f_sl_flag_enabled = { fg = c.black, bg = c.nord_blue },
    f_sl_flag_scope = { fg = c.black, bg = c.baby_pink },
    f_sl_noice_command = { fg = c.white, bg = t and "none" or c.statusline_bg },
    f_sl_noice_mode = { fg = c.yellow, bg = t and "none" or c.statusline_bg },
    f_sl_readonly = { fg = c.orange, bg = t and "none" or c.statusline_bg },
    f_sl_text = { fg = c.white, bg = t and "none" or c.statusline_bg },
    f_sl_text_command = { fg = c.vibrant_green, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_confirm = { fg = c.teal, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_insert = { fg = c.dark_purple, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_normal = { fg = c.nord_blue, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_nterminal = { fg = c.yellow, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_replace = { fg = c.orange, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_select = { fg = c.blue, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_terminal = { fg = c.green, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_visual = { fg = c.cyan, bg = t and "none" or c.statusline_bg },
    f_sl_username = { fg = c.black, bg = c.cyan },

    ---tabline
    f_tl_bg = { fg = t and "none" or c.statusline_bg, bg = t and "none" or c.statusline_bg },
    f_tl_buf_item = { fg = c.light_grey, bg = t and "none" or c.black2 },
    f_tl_buf_item_cur = { fg = c.white, bg = t and "none" or c.black },
    f_tl_buf_left_pad = { fg = c.light_grey, bg = t and "none" or c.black2 },
    f_tl_buf_left_pad_cur = { fg = c.blue, bg = t and "none" or c.black },
    f_tl_buf_mod = { fg = c.red, bg = t and "none" or c.black2 },
    f_tl_buf_mod_cur = { fg = c.green, bg = t and "none" or c.black },
    f_tl_buf_title = { fg = c.light_grey, bg = t and "none" or c.black2 },
    f_tl_buf_title_cur = { fg = c.white, bg = t and "none" or c.black },
    f_tl_neotree_blank = { fg = c.white, bg = t and "none" or c.black2 },
    f_tl_neotree_text = { fg = c.blue, bg = t and "none" or c.black2 },
    f_tl_search_blank = { fg = c.white, bg = t and "none" or c.black2 },
    f_tl_search_text = { fg = c.blue, bg = t and "none" or c.black2 },
    f_tl_tab_add = { fg = c.white, bg = c.one_bg2 },
    f_tl_tab_item = { fg = c.white, bg = c.black2 },
    f_tl_tab_item_cur = { fg = c.red },
    f_tl_tab_toggle = { fg = c.black, bg = c.blue },

    ---winline
    f_wl_bg = { fg = t and "none" or c.statusline_bg, bg = t and "none" or c.statusline_bg },
    f_wl_dirpath_text = { fg = c.white, bg = t and "none" or c.statusline_bg },
    f_wl_filename_text = { fg = c.white, bg = t and "none" or c.statusline_bg },
    f_wl_context_sep = { fg = c.white, bg = t and "none" or c.statusline_bg },
    f_wl_context_icon = { fg = c.purple, bg = t and "none" or c.statusline_bg },
    f_wl_context_text = { fg = c.white, bg = t and "none" or c.statusline_bg },

    ---replace
    f_sr_filepath = { fg = c.blue, bg = "none" },
    f_sr_flag = { fg = c.white, bg = c.grey },
    f_sr_flag_enabled = { fg = c.black, bg = c.baby_pink },
    f_sr_invisible = { fg = "none", bg = "none" },
    f_sr_opt_name = { fg = c.blue, bg = "none", bold = true },
    f_sr_opt_replace_pattern = { fg = c.diff_add_word, bg = "none" },
    f_sr_opt_search_pattern = { fg = c.diff_del_word, bg = "none" },
    f_sr_opt_value = { fg = c.yellow, bg = "none" },
    f_sr_result_fence = { fg = c.grey, bg = "none" },
    f_sr_text_added = { fg = c.diff_add_word, bg = "none" },
    f_sr_text_deleted = { fg = c.diff_del_word, strikethrough = true },
    f_sr_usage = { fg = c.grey_fg2, bg = "none" },
  }
end

return gen_hlgroup
