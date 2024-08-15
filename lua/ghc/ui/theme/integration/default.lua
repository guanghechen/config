---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

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

    ---search
    f_us_input_border = { fg = c.black2, bg = c.black2 },
    f_us_input_normal = { fg = c.white, bg = c.black2 },
    f_us_input_prompt = { fg = c.red, bg = c.black2 },
    f_us_input_title = { fg = c.black, bg = c.red },
    f_us_main_bg = { bg = c.darker_black },
    f_us_main_border = { fg = c.darker_black, bg = c.darker_black },
    f_us_main_current = { bg = c.one_bg2 },
    f_us_main_match = { fg = c.blue },
    f_us_main_match_lnum = { fg = c.grey },
    f_us_main_normal = { bg = c.darker_black },
    f_us_main_replace = { fg = c.diff_add_word },
    f_us_main_search = { fg = c.diff_del_word, strikethrough = true },
    f_us_preview_current = { bg = c.one_bg2 },
    f_us_preview_border = { fg = c.darker_black, bg = c.darker_black },
    f_us_preview_normal = { bg = c.darker_black },
    f_us_preview_title = { fg = c.black, bg = c.green },
    f_us_preview_error = { fg = c.red, bold = true },
    f_us_match = { fg = c.black, bg = c.yellow },
    f_us_match_cur = { fg = c.black, bg = c.red },

    ---textarea
    f_ut_current = { bg = c.one_bg2 },
    f_ut_border = { fg = c.darker_pink },
    f_ut_normal = { bg = c.black2 },
  }
end

return gen_hlgroup_map
