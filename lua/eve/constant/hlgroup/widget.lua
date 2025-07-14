---@class eve.constant.hlgroup.widget
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = std.color
  local c = context.scheme.palette ---@type std.t.theme.IPalette
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
    f_fold_virt_text = { fg = c.bg2, bg = c.yellow, italic = true },
    f_fold_virt_text_inv = { fg = c.yellow, bg = t and c.bg0 or c.none, italic = true },

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

    ---indentline
    indentline_0 = { fg = c.bg1 },
    indentline_1 = { fg = cs.mix(c.bg0, c.red, 20) },
    indentline_2 = { fg = cs.mix(c.bg0, c.green, 20) },
    indentline_3 = { fg = cs.mix(c.bg0, c.yellow, 20) },
    indentline_4 = { fg = cs.mix(c.bg0, c.blue, 20) },
    indentline_5 = { fg = cs.mix(c.bg0, c.purple, 20) },
    indentline_6 = { fg = cs.mix(c.bg0, c.aqua, 20) },
    indentline_7 = { fg = cs.mix(c.bg0, c.orange, 20) },

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
    f_fe_name_dir = { fg = c.blue },
    f_fe_name_file = { fg = c.fg1 },
    f_fe_owner = { fg = c.red },
    f_fe_perm_dir = { fg = c.blue },
    f_fe_perm_file = { fg = c.fg1 },
    f_fe_perm = { fg = c.fg1 },
    f_fe_size = { fg = c.green },

    ---filetree
    f_ft_dirname = { fg = c.blue },
    f_ft_filename = { fg = c.fg2 },
    f_ft_pathsep = { fg = c.fg4 },
    f_ft_position = { fg = c.bg4 },
    f_ft_reference = { fg = c.purple, bold = true, italic = true },
    f_ft_text = { fg = c.fg4 },

    ---git hunk preview
    f_ghp_cursor = { bg = c.bg3 },
    f_ghp_normal = { bg = c.bg1 },

    ---cmdline
    f_uc_border = { link = "FloatActiveBorder" },
    f_uc_icon_command = { fg = c.aqua, bg = t and c.bg0 or c.none },
    f_uc_icon_command_help = { fg = c.purple, bg = t and c.bg0 or c.none },
    f_uc_icon_command_lua = { fg = c.blue, bg = t and c.bg0 or c.none },
    f_uc_icon_search_forward = { fg = c.yellow, bg = t and c.bg0 or c.none },
    f_uc_icon_search_backward = { fg = c.yellow, bg = t and c.bg0 or c.none },
    f_uc_option = { fg = c.fg1, bg = c.bg1 },
    f_uc_option_current = { fg = c.bg0, bg = c.pink, bold = true },
    f_uc_type_lua = { fg = c.blue, bg = t and c.bg0 or c.none },

    ---input
    f_ui_current = { bg = t and c.bg0 or c.none },
    f_ui_normal = { bg = t and c.bg0 or c.none },

    ---lsp symbols
    f_lsp_symbol_icon = { fg = c.brightPurple },
    f_lsp_symbol_icon_Array = { fg = c.blue },
    f_lsp_symbol_icon_Boolean = { fg = c.orange },
    f_lsp_symbol_icon_Class = { fg = c.brightAqua },
    f_lsp_symbol_icon_Color = { fg = c.fg1 },
    f_lsp_symbol_icon_Constant = { fg = c.orange },
    f_lsp_symbol_icon_Constructor = { fg = c.blue },
    f_lsp_symbol_icon_Enum = { fg = c.blue },
    f_lsp_symbol_icon_EnumMember = { fg = c.brightPurple },
    f_lsp_symbol_icon_Event = { fg = c.yellow },
    f_lsp_symbol_icon_Field = { fg = c.red },
    f_lsp_symbol_icon_File = { fg = c.fg1 },
    f_lsp_symbol_icon_Folder = { fg = c.fg1 },
    f_lsp_symbol_icon_Function = { fg = c.blue },
    f_lsp_symbol_icon_Identifier = { fg = c.red },
    f_lsp_symbol_icon_Interface = { fg = c.green },
    f_lsp_symbol_icon_Key = { fg = c.red },
    f_lsp_symbol_icon_Keyword = { fg = c.fg1 },
    f_lsp_symbol_icon_Method = { fg = c.blue },
    f_lsp_symbol_icon_Module = { fg = c.yellow },
    f_lsp_symbol_icon_Namespace = { fg = c.brightAqua },
    f_lsp_symbol_icon_Null = { fg = c.aqua },
    f_lsp_symbol_icon_Number = { fg = c.orange },
    f_lsp_symbol_icon_Object = { fg = c.brightPurple },
    f_lsp_symbol_icon_Operator = { fg = c.fg1 },
    f_lsp_symbol_icon_Package = { fg = c.green },
    f_lsp_symbol_icon_Property = { fg = c.red },
    f_lsp_symbol_icon_Reference = { fg = c.fg1 },
    f_lsp_symbol_icon_Snippet = { fg = c.red },
    f_lsp_symbol_icon_String = { fg = c.green },
    f_lsp_symbol_icon_Struct = { fg = c.brightPurple },
    f_lsp_symbol_icon_Structure = { fg = c.brightPurple },
    f_lsp_symbol_icon_Text = { fg = c.green },
    f_lsp_symbol_icon_Type = { fg = c.yellow },
    f_lsp_symbol_icon_TypeParameter = { fg = c.red },
    f_lsp_symbol_icon_Unit = { fg = c.brightPurple },
    f_lsp_symbol_icon_Value = { fg = c.aqua },
    f_lsp_symbol_icon_Variable = { fg = c.brightPurple },
    f_lsp_symbol_sep = { fg = c.bg4 },
    f_lsp_symbol_text = { fg = c.fg2 },

    ---message
    f_um_search_count = { fg = c.yellow },

    ---notify
    -- stylua: ignore start
    f_un_border_trace = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_un_border_debug = { fg = c.green,   bg = t and c.bg0 or c.none },
    f_un_border_info  = { fg = c.blue,    bg = t and c.bg0 or c.none },
    f_un_border_warn  = { fg = c.yellow,  bg = t and c.bg0 or c.none },
    f_un_border_error = { fg = c.red,     bg = t and c.bg0 or c.none },
    f_un_icon_trace   = { fg = c.fg2,     bg = c.none },
    f_un_icon_debug   = { fg = c.green,   bg = c.none },
    f_un_icon_info    = { fg = c.blue,    bg = c.none },
    f_un_icon_warn    = { fg = c.yellow,  bg = c.none },
    f_un_icon_error   = { fg = c.red,     bg = c.none },
    f_un_level_trace  = { fg = c.fg2,     bg = c.none },
    f_un_level_debug  = { fg = c.green,   bg = c.none },
    f_un_level_info   = { fg = c.blue,    bg = c.none },
    f_un_level_warn   = { fg = c.yellow,  bg = c.none },
    f_un_level_error  = { fg = c.red,     bg = c.none },
    f_un_normal_trace = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_un_normal_debug = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_un_normal_info  = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_un_normal_warn  = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_un_normal_error = { fg = c.fg2,     bg = t and c.bg0 or c.none },
    f_un_title_trace  = { fg = c.fg2,     bg = c.none },
    f_un_title_debug  = { fg = c.green,   bg = c.none },
    f_un_title_info   = { fg = c.blue,    bg = c.none },
    f_un_title_warn   = { fg = c.yellow,  bg = c.none },
    f_un_title_error  = { fg = c.red,     bg = c.none },
    f_un_winbar_trace = { fg = c.fg2,     bg = c.none, sp = c.bg2,    bold = true, underline = true },
    f_un_winbar_debug = { fg = c.green,   bg = c.none, sp = c.green,  bold = true, underline = true },
    f_un_winbar_info  = { fg = c.blue,    bg = c.none, sp = c.blue,   bold = true, underline = true },
    f_un_winbar_warn  = { fg = c.yellow,  bg = c.none, sp = c.yellow, bold = true, underline = true },
    f_un_winbar_error = { fg = c.red,     bg = c.none, sp = c.red,    bold = true, underline = true },
    -- stylua: ignore end

    ---picker
    f_pk_finder_normal = { fg = c.fg1, bg = t and c.bg0 or c.none },
    f_pk_finder_title = { link = t and "ms_b_bg0" or "ms_b_none" },
    f_pk_matches = { fg = c.pink, bold = true, italic = true },
    f_pk_finder_prompt = { fg = c.red, bg = t and c.bg0 or c.none },
    f_pk_preview_current = { bg = c.bg2 },
    f_pk_preview_normal = { bg = bg_preview },
    f_pk_preview_title = { fg = c.green, bg = t and c.bg0 or c.none, bold = true },
    f_pk_result_current = { bg = c.bg3 },
    f_pk_result_normal = { bg = bg_main },
    f_pk_sign_line_current = { bg = c.bg3 },
    f_pk_sign_line_present = { fg = c.pink, bg = c.none, bold = true },
    f_pk_sign_line_present_current = { fg = c.pink, bg = c.bg3, bold = true },
    f_pk_sign_line_selected = { fg = c.purple, bg = c.none },
    f_pk_sign_line_selected_current = { fg = c.purple, bg = c.bg3 },

    ---searcher
    f_ss_matches = { fg = c.pink, bold = true, italic = true },
    f_ss_search = { fg = c.red, bold = true, italic = true, strikethrough = true },
    f_ss_replace = { fg = c.green, bold = true, italic = true },
    f_ss_preview_error = { fg = c.red, bold = true },
    f_ss_preview_match = { fg = c.bg1, bg = c.yellow },
    f_ss_preview_match_cur = { fg = c.bg1, bg = c.red, bold = true, underline = true },
    f_ss_preview_search = { fg = c.fg1, bg = c.diffDel, strikethrough = true },
    f_ss_preview_search_cur = { fg = c.bg1, bg = c.red, bold = true, strikethrough = true },
    f_ss_preview_replace = { fg = c.bg1, bg = c.diffAdd },
    f_ss_preview_replace_cur = { fg = c.bg1, bg = c.green, bold = true },

    ---popupmenu
    f_up_normal = { fg = c.fg2, bg = t and c.none or c.bg0 },
    f_up_border = { link = t and "ms_b_bg0" or "ms_b_none" },
    f_up_selected = { fg = c.bg1, bg = c.blue, bold = true, italic = true },

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

    ---treeview
    f_utw_indent = { fg = c.bg2 },
    f_utw_indent_float = { fg = c.bg4 },

    ---vim options
    f_us_vo_name = { fg = c.fg1 },
    f_us_vo_type = { fg = c.orange },
    f_us_vo_scope = { fg = c.red, bold = true },
    f_us_vo_value = { fg = c.fg3 },

    ---winsep
    f_winsep_border = {},
    f_winsep_normal = { link = "ms_bg0" },
    f_winsep_title = {},
  }
end

return M
