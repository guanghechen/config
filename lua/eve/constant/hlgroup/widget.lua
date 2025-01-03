local cs = require("eve.builtin.color")

---@param context                       eve.t.theme.IContext
---@return table<string, eve.t.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type eve.t.theme.IPalette
  local t = context.transparency ---@type boolean

  local bg_main = t and c.bg0 or "none" ---@type string
  local bg_preview = t and c.bg0 or "none" ---@type string

  return {
    ---common
    f_lnum_error = { fg = c.red },
    f_lnum_warn = { fg = c.yellow },
    f_lnum_info = { fg = c.green },
    f_lnum_hint = { fg = c.purple },
    f_transparent = { bg = "none" },

    ---buffers
    f_buf_nr = { fg = c.fg4 },
    f_buf_filetype = { fg = c.fg3 },
    f_buf_filepath = { fg = c.fg2 },

    ---hipairs
    f_hipairs_1 = { fg = c.red, bg = c.bg4, bold = true },
    f_hipairs_2 = { fg = c.green, bg = c.bg2, bold = true },
    f_hipairs_3 = { fg = c.yellow, bg = c.bg2, bold = true },
    f_hipairs_4 = { fg = c.blue, bg = c.bg2, bold = true },
    f_hipairs_5 = { fg = c.purple, bg = c.bg2, bold = true },
    f_hipairs_6 = { fg = c.aqua, bg = c.bg2, bold = true },
    f_hipairs_7 = { fg = c.orange, bg = c.bg2, bold = true },

    ---diff
    f_diff_add_left = { bg = c.diffDel, fg = "none" },
    f_diff_add_right = { bg = c.diffAdd, fg = "none" },
    f_diff_del_left = { bg = c.diffDel, fg = "none" },
    f_diff_del_right = { bg = c.diffDel, fg = "none" },
    f_diff_mod_left = { bg = c.diffDel, fg = "none" },
    f_diff_mod_right = { bg = c.diffAdd, fg = "none" },
    f_diff_word_left = { bg = c.diffDelInline, fg = "none" },
    f_diff_word_right = { bg = c.diffAddInline, fg = "none" },

    ---file explorer
    f_fe_date = { fg = c.fg4 },
    f_fe_group = { fg = c.red },
    f_fe_match = { fg = c.red },
    f_fe_name_dir = { fg = c.blue },
    f_fe_name_file = { fg = c.fg1 },
    f_fe_owner = { fg = c.red },
    f_fe_perm_dir = { fg = c.blue },
    f_fe_perm_file = { fg = c.fg1 },
    f_fe_perm = { fg = c.fg1 },
    f_fe_size = { fg = c.green },

    ---git hunk preview
    f_ghp_cursor = { bg = c.bg3 },
    f_ghp_border = { fg = c.bg1, bg = c.bg1 },
    f_ghp_normal = { bg = c.bg1 },

    ---search
    f_us_border = { fg = c.bg2, bg = t and c.bg0 or "none" },
    f_us_border_active = { fg = c.purple, bg = t and c.bg0 or "none" },
    f_us_input_normal = { fg = c.fg1, bg = t and c.bg0 or "none" },
    f_us_input_prompt = { fg = c.red, bg = t and c.bg0 or "none" },
    f_us_input_title = { fg = c.red, bg = t and c.bg0 or "none" },
    f_us_main_bg = { bg = bg_main },
    f_us_main_current = { bg = c.bg3 },
    f_us_main_match = { fg = c.blue },
    f_us_main_match_lnum = { fg = c.fg4 },
    f_us_main_present = { fg = c.blue, bg = "none" },
    f_us_main_present_cur = { fg = c.blue, bg = c.bg3 },
    f_us_main_normal = { bg = bg_main },
    f_us_main_replace = { fg = c.green },
    f_us_main_search = { fg = c.red, strikethrough = true },
    f_us_preview_current = { bg = c.bg2 },
    f_us_preview_error = { fg = c.red, bold = true },
    f_us_preview_normal = { bg = bg_preview },
    f_us_preview_search = { fg = c.fg1, bg = c.diffDel, strikethrough = true },
    f_us_preview_search_cur = { fg = c.bg1, bg = c.red, bold = true, strikethrough = true },
    f_us_preview_replace = { fg = c.bg1, bg = c.diffAdd },
    f_us_preview_replace_cur = { fg = c.bg1, bg = c.green, bold = true },
    f_us_preview_title = { fg = c.green, bg = t and c.bg0 or "none" },
    f_us_match = { fg = c.bg1, bg = c.yellow },
    f_us_match_cur = { fg = c.bg1, bg = c.red, bold = true, underline = true },

    ---select codeaction
    f_us_codeaction_order = { fg = c.red, bg = "none" },
    f_us_codeaction_content = { fg = c.fg1, bg = "none" },
    f_us_codeaction_client_name = { fg = c.fg4, bg = "none" },

    ---terminal
    f_us_terminal_bg = { bg = c.bg0 },
    f_us_terminal_border = { fg = c.purple, bg = c.bg0 },
    f_us_terminal_current = { bg = c.bg2 },

    ---textarea
    f_ut_current = { bg = c.bg3 },
    f_ut_border = { fg = c.brightOrange },
    f_ut_normal = { bg = c.bg1 },

    ---vim options
    f_us_vo_name = { fg = c.purple },
    f_us_vo_type = { fg = c.orange },
    f_us_vo_scope = { fg = c.red, bold = true },
    f_us_vo_value = { fg = c.fg1 },

    ---winsep
    f_winsep_left_border = { fg = c.purple, bold = true },
    f_winsep_top_border = { fg = c.purple, bold = true },
    f_winsep_right_border = { fg = c.purple, bold = true },
    f_winsep_bottom_border = { fg = c.purple, bold = true },
    f_winsep_fixed = { fg = c.purple, bold = true },
    f_winsep_float = { fg = cs.mix(c.bg0, c.purple, 70), bg = t and c.bg0 or "none", bold = false },
  }
end

return gen_hlgroup_map
