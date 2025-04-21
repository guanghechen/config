---@class eve.constant.hlgroup.widget
local M = {}

---@param context                       eve.t.theme.IContext
---@return table<string, eve.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type eve.t.theme.IPalette
  local t = context.transparency ---@type boolean

  local bg_main = t and c.bg0 or c.none ---@type string
  local bg_preview = t and c.bg0 or c.none ---@type string

  return {
    ---common
    f_lnum_error = { fg = c.red },
    f_lnum_warn = { fg = c.yellow },
    f_lnum_info = { fg = c.green },
    f_lnum_hint = { fg = c.purple },
    f_transparent = { bg = c.none },

    ---buffers
    f_buf_nr = { fg = c.fg4 },
    f_buf_filetype = { fg = c.fg3 },
    f_buf_filepath = { fg = c.fg2 },

    ---hipairs
    f_hipairs_1 = { fg = c.red, bold = true, italic = true },
    f_hipairs_2 = { fg = c.green, bold = true, italic = true },
    f_hipairs_3 = { fg = c.yellow, bold = true, italic = true },
    f_hipairs_4 = { fg = c.blue, bold = true, italic = true },
    f_hipairs_5 = { fg = c.purple, bold = true, italic = true },
    f_hipairs_6 = { fg = c.aqua, bold = true, italic = true },
    f_hipairs_7 = { fg = c.orange, bold = true, italic = true },

    ---diff
    f_diff_add_left = { bg = c.diffDel, fg = c.none },
    f_diff_add_right = { bg = c.diffAdd, fg = c.none },
    f_diff_del_left = { bg = c.diffDel, fg = c.none },
    f_diff_del_right = { bg = c.diffDel, fg = c.none },
    f_diff_mod_left = { bg = c.diffDel, fg = c.none },
    f_diff_mod_right = { bg = c.diffAdd, fg = c.none },
    f_diff_word_left = { bg = c.diffDelInline, fg = c.none },
    f_diff_word_right = { bg = c.diffAddInline, fg = c.none },

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
    f_ghp_normal = { bg = c.bg1 },

    ---input
    f_ui_current = { bg = t and c.bg0 or c.none },
    f_ui_normal = { bg = t and c.bg0 or c.none },

    ---notify
    -- stylua: ignore start
    f_notify_border_trace = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_notify_border_debug = { fg = c.green,   bg = t and c.bg0 or c.none },
    f_notify_border_info  = { fg = c.blue,    bg = t and c.bg0 or c.none },
    f_notify_border_warn  = { fg = c.yellow,  bg = t and c.bg0 or c.none },
    f_notify_border_error = { fg = c.red,     bg = t and c.bg0 or c.none },
    f_notify_normal_trace = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_notify_normal_debug = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_notify_normal_info  = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_notify_normal_warn  = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_notify_normal_error = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_notify_winbar_trace = { fg = c.fg2,     bg = c.none, sp = c.bg2,     underline = true },
    f_notify_winbar_debug = { fg = c.green,   bg = c.none, sp = c.green,     underline = true },
    f_notify_winbar_info  = { fg = c.blue,    bg = c.none, sp = c.blue,    underline = true },
    f_notify_winbar_warn  = { fg = c.yellow,  bg = c.none, sp = c.yellow,  underline = true },
    f_notify_winbar_error = { fg = c.red,     bg = c.none, sp = c.red,     underline = true },
    -- stylua: ignore end

    ---search
    f_us_input_normal = { fg = c.fg1, bg = t and c.bg0 or c.none },
    f_us_input_prompt = { fg = c.red, bg = t and c.bg0 or c.none },
    f_us_input_title = { link = t and "ms_b_bg0" or "ms_b_none" },
    f_us_main_bg = { bg = bg_main },
    f_us_main_current = { bg = c.bg3 },
    f_us_main_match = { fg = c.blue },
    f_us_main_match_lnum = { fg = c.fg4 },
    f_us_main_present = { fg = c.blue, bg = c.none },
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
    f_us_preview_title = { fg = c.green, bg = t and c.bg0 or c.none, bold = true },
    f_us_match = { fg = c.bg1, bg = c.yellow },
    f_us_match_cur = { fg = c.bg1, bg = c.red, bold = true, underline = true },

    ---select codeaction
    f_us_codeaction_order = { fg = c.red, bg = c.none },
    f_us_codeaction_content = { fg = c.fg1, bg = c.none },
    f_us_codeaction_client_name = { fg = c.fg4, bg = c.none },

    ---signs
    fs_input_prompt = { fg = c.red, bg = t and c.bg0 or c.none },
    fs_main_current = { bg = c.bg3 },
    fs_main_present = { fg = c.blue, bg = c.none },
    fs_main_present_cur = { fg = c.blue, bg = c.bg3 },
    fs_main_selected = { fg = c.purple, bg = c.none },
    fs_main_selected_cur = { fg = c.purple, bg = c.bg3 },

    ---terminal
    f_us_terminal_bg = { bg = c.bg0 },
    f_us_terminal_current = { bg = c.bg2 },

    ---textarea
    f_ut_current = { bg = c.bg3 },
    f_ut_normal = { bg = t and c.none or c.bg0 },

    ---vim options
    f_us_vo_name = { fg = c.purple },
    f_us_vo_type = { fg = c.orange },
    f_us_vo_scope = { fg = c.red, bold = true },
    f_us_vo_value = { fg = c.fg1 },

    ---winsep
    f_winsep_border = { link = t and "ms_b_bg0" or "ms_b_none" },
    f_winsep_normal = { link = "ms_b_none" },
    f_winsep_title = { link = "ms_b_none" },
  }
end

return M
