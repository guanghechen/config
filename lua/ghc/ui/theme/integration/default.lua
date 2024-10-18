---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

  return {
    ---common
    f_lnum_error = { fg = c.red },
    f_lnum_warn = { fg = c.yellow },
    f_lnum_info = { fg = c.green },
    f_lnum_hint = { fg = c.purple },
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

    ---file explorer
    f_fe_date = { fg = c.grey },
    f_fe_group = { fg = c.red },
    f_fe_match = { fg = c.red },
    f_fe_name_dir = { fg = c.blue },
    f_fe_name_file = { fg = c.fg0 },
    f_fe_owner = { fg = c.red },
    f_fe_perm_dir = { fg = c.blue },
    f_fe_perm_file = { fg = c.fg0 },
    f_fe_perm = { fg = c.fg0 },
    f_fe_size = { fg = c.green },

    ---search
    f_us_input_border = { fg = c.black, bg = c.bg1 },
    f_us_input_normal = { fg = c.fg0, bg = c.bg1 },
    f_us_input_prompt = { fg = c.red, bg = c.bg1 },
    f_us_input_title = { fg = c.black, bg = c.red },
    f_us_main_bg = { bg = c.bg0 },
    f_us_main_border = { fg = c.dark_black, bg = c.bg0 },
    f_us_main_current = { bg = c.bg3 },
    f_us_main_match = { fg = c.blue },
    f_us_main_match_lnum = { fg = c.grey },
    f_us_main_present = { fg = c.blue, bg = c.dark_black },
    f_us_main_present_cur = { fg = c.blue, bg = c.bg2 },
    f_us_main_normal = { bg = c.bg0 },
    f_us_main_replace = { fg = c.diff_add_word },
    f_us_main_search = { fg = c.diff_del_word, strikethrough = true },
    f_us_preview_current = { bg = c.bg2 },
    f_us_preview_border = { fg = c.bg1, bg = c.bg0 },
    f_us_preview_error = { fg = c.red, bold = true },
    f_us_preview_normal = { bg = c.bg0 },
    f_us_preview_search = { fg = c.black, bg = c.diff_del, strikethrough = true },
    f_us_preview_search_cur = { fg = c.black, bg = c.red, bold = true, strikethrough = true },
    f_us_preview_replace = { fg = c.black, bg = c.diff_add },
    f_us_preview_replace_cur = { fg = c.black, bg = c.green, bold = true },
    f_us_preview_title = { fg = c.black, bg = c.green },
    f_us_match = { fg = c.black, bg = c.yellow },
    f_us_match_cur = { fg = c.black, bg = c.red, bold = true, underline = true },

    ---select codeaction
    f_us_codeaction_order = { fg = c.red, bg = "none" },
    f_us_codeaction_content = { fg = c.fg0, bg = "none" },
    f_us_codeaction_client_name = { fg = c.grey, bg = "none" },

    ---textarea
    f_ut_current = { bg = c.bg3 },
    f_ut_border = { fg = c.dark_pink },
    f_ut_normal = { bg = c.bg1 },

    ---vim options
    f_us_vo_name = { fg = c.purple },
    f_us_vo_type = { fg = c.dark_yellow },
    f_us_vo_scope = { fg = c.red, bold = true },
    f_us_vo_value = { fg = c.fg0 },
  }
end

return gen_hlgroup_map
