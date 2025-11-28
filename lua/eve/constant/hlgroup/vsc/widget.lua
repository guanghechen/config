---@class eve.constant.hlgroup.vsc.widget
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = std.color
  local u = context.scheme.palette.unified ---@type std.t.theme.UnifiedPalette
  local c = context.scheme.palette.vsc ---@type std.t.theme.IVscPalette
  local t = context.transparency ---@type boolean

  local bg = t and c.none or u.bg0 ---@type string
  local bg_pane = t and u.bg0 or c.none ---@type string

  return {
    ---buffers
    f_buf_nr = { fg = u.fg4 },
    f_buf_filetype = { fg = u.fg3 },
    f_buf_filepath = { fg = u.fg2 },

    ---cmdline
    f_uc_border = { link = "FloatActiveBorder" },
    f_uc_icon_command = { fg = u.aqua, bg = bg },
    f_uc_icon_command_help = { fg = u.purple, bg = bg },
    f_uc_icon_command_lua = { fg = u.blue, bg = bg },
    f_uc_icon_search_forward = { fg = u.yellow, bg = bg },
    f_uc_icon_search_backward = { fg = u.yellow, bg = bg },
    f_uc_option = { fg = u.fg1, bg = u.bg1 },
    f_uc_option_current = { fg = u.bg0, bg = u.pink, bold = true },
    f_uc_type_lua = { fg = u.blue, bg = bg },

    ---common
    f_lnum_error = { fg = u.red },
    f_lnum_warn = { fg = u.yellow },
    f_lnum_info = { fg = u.green },
    f_lnum_hint = { fg = u.purple },
    f_transparent = { bg = c.none },
    f_fold_virt_text = { fg = u.bg2, bg = u.yellow, italic = true },
    f_fold_virt_text_inv = { fg = u.yellow, bg = bg, italic = true },

    ---diff
    f_diff_add_left = { bg = u.diffDel },
    f_diff_add_right = { bg = u.diffAdd },
    f_diff_del_left = { bg = u.diffDel },
    f_diff_del_right = { bg = u.diffDel },
    f_diff_mod_left = { bg = u.diffDel },
    f_diff_mod_right = { bg = u.diffAdd },
    f_diff_word_left = { bg = u.diffDelInline },
    f_diff_word_right = { bg = u.diffAddInline },

    ---file explorer
    f_fe_date = { fg = u.fg4 },
    f_fe_group = { fg = u.red },
    f_fe_name_dir = { fg = u.blue },
    f_fe_name_file = { fg = u.fg1 },
    f_fe_owner = { fg = u.red },
    f_fe_perm_dir = { fg = u.blue },
    f_fe_perm_file = { fg = u.fg1 },
    f_fe_perm = { fg = u.fg1 },
    f_fe_size = { fg = u.green },

    ---filetree
    f_ft_dirname = { fg = u.brightBlue },
    f_ft_filename = { fg = u.fg2 },
    f_ft_pathsep = { fg = u.fg4 },
    f_ft_position = { fg = u.bg4 },
    f_ft_reference = { fg = u.purple, bold = true, italic = true },
    f_ft_text = { fg = u.fg4 },
    f_ft_git_add = { fg = u.brightGreen, bold = true },
    f_ft_git_change = { fg = u.brightYellow, bold = true },
    f_ft_git_delete = { fg = u.brightRed, bold = true },
    f_ft_git_rename = { fg = u.brightBlue, bold = true },
    f_ft_git_untracked = { fg = u.fg4, bold = true },
    f_ft_git_ignored = { fg = u.fg4, bold = true },
    f_ft_git_unmerged = { fg = u.brightOrange, bold = true },
    f_ft_git_staged = { fg = u.brightGreen, bold = true },
    f_ft_git_unstaged = { fg = u.brightYellow, bold = true },
    f_ft_git_other = { fg = u.fg3, bold = true },

    ---git hunk preview
    f_ghp_cursor = { bg = u.bg3 },
    f_ghp_normal = { bg = u.bg1 },

    ---matched pairs
    f_matched_pairs_0 = { fg = c.editorBracket_fg1, bg = u.bg4, bold = true },
    f_matched_pairs_1 = { fg = c.editorBracket_fg1 },
    f_matched_pairs_2 = { fg = c.editorBracket_fg2 },
    f_matched_pairs_3 = { fg = c.editorBracket_fg3 },
    f_matched_pairs_4 = { fg = c.editorBracket_fg4 },
    f_matched_pairs_5 = { fg = c.editorBracket_fg5 },
    f_matched_pairs_6 = { fg = c.editorBracket_fg6 },
    f_unmatched_pairs = { fg = c.editorBracket_fg0 },

    ---hipatterns
    f_hipattern_error = { fg = c.base, bg = c.accentRed, bold = true, italic = true, underline = true },
    f_hipattern_warn = { fg = c.base, bg = c.warning, bold = true, italic = true, underline = true },
    f_hipattern_todo = { fg = c.base, bg = c.accentPurple, bold = true, italic = true, underline = true },
    f_hipattern_info = { fg = c.base, bg = c.accentBlue, bold = true, italic = true, underline = true },
    f_hipattern_success = { fg = c.base, bg = c.success, bold = true, italic = true, underline = true },
    f_hipattern_hint = { fg = c.base, bg = c.accentAqua, bold = true, italic = true, underline = true },
    f_hipattern_quote = { fg = c.base, bg = c.textDim, bold = true, italic = true, underline = true },

    ---indentline
    f_indentline_1 = { fg = cs.mix(u.bg0, u.red, 20) },
    f_indentline_2 = { fg = cs.mix(u.bg0, u.orange, 20) },
    f_indentline_3 = { fg = cs.mix(u.bg0, u.yellow, 20) },
    f_indentline_4 = { fg = cs.mix(u.bg0, u.green, 20) },
    f_indentline_5 = { fg = cs.mix(u.bg0, u.aqua, 20) },
    f_indentline_6 = { fg = cs.mix(u.bg0, u.blue, 20) },
    f_indentline_7 = { fg = cs.mix(u.bg0, u.purple, 20) },

    ---indentscope
    f_indentscope_1 = { fg = cs.mix(u.bg0, u.red, 80), bold = true },
    f_indentscope_2 = { fg = cs.mix(u.bg0, u.orange, 80), bold = true },
    f_indentscope_3 = { fg = cs.mix(u.bg0, u.yellow, 80), bold = true },
    f_indentscope_4 = { fg = cs.mix(u.bg0, u.green, 80), bold = true },
    f_indentscope_5 = { fg = cs.mix(u.bg0, u.aqua, 80), bold = true },
    f_indentscope_6 = { fg = cs.mix(u.bg0, u.blue, 80), bold = true },
    f_indentscope_7 = { fg = cs.mix(u.bg0, u.purple, 80), bold = true },

    ---indent underline
    f_indent_underline_1 = { sp = cs.mix(u.bg0, u.red, 50), underline = true },
    f_indent_underline_2 = { sp = cs.mix(u.bg0, u.orange, 50), underline = true },
    f_indent_underline_3 = { sp = cs.mix(u.bg0, u.yellow, 50), underline = true },
    f_indent_underline_4 = { sp = cs.mix(u.bg0, u.green, 50), underline = true },
    f_indent_underline_5 = { sp = cs.mix(u.bg0, u.aqua, 50), underline = true },
    f_indent_underline_6 = { sp = cs.mix(u.bg0, u.blue, 50), underline = true },
    f_indent_underline_7 = { sp = cs.mix(u.bg0, u.purple, 50), underline = true },

    ---input
    f_ui_current = { bg = u.bg3 },
    f_ui_normal = { bg = bg_pane },

    ---lsp
    f_lsp_diagnostic_error = { fg = u.red, bg = bg_pane },
    f_lsp_diagnostic_warn = { fg = u.yellow, bg = bg_pane },
    f_lsp_diagnostic_hint = { fg = u.purple, bg = bg_pane },
    f_lsp_diagnostic_info = { fg = u.green, bg = bg_pane },

    ---lsp symbols
    f_lsp_symbol_icon = { fg = u.brightPurple },
    f_lsp_symbol_icon_Array = { fg = u.blue },
    f_lsp_symbol_icon_Boolean = { fg = u.orange },
    f_lsp_symbol_icon_Class = { fg = u.brightAqua },
    f_lsp_symbol_icon_Color = { fg = u.fg1 },
    f_lsp_symbol_icon_Constant = { fg = u.orange },
    f_lsp_symbol_icon_Constructor = { fg = u.blue },
    f_lsp_symbol_icon_Enum = { fg = u.blue },
    f_lsp_symbol_icon_EnumMember = { fg = u.brightPurple },
    f_lsp_symbol_icon_Event = { fg = u.yellow },
    f_lsp_symbol_icon_Field = { fg = u.red },
    f_lsp_symbol_icon_File = { fg = u.fg1 },
    f_lsp_symbol_icon_Folder = { fg = u.fg1 },
    f_lsp_symbol_icon_Function = { fg = u.blue },
    f_lsp_symbol_icon_Identifier = { fg = u.red },
    f_lsp_symbol_icon_Interface = { fg = u.green },
    f_lsp_symbol_icon_Key = { fg = u.red },
    f_lsp_symbol_icon_Keyword = { fg = u.fg1 },
    f_lsp_symbol_icon_Method = { fg = u.blue },
    f_lsp_symbol_icon_Module = { fg = u.yellow },
    f_lsp_symbol_icon_Namespace = { fg = u.brightAqua },
    f_lsp_symbol_icon_Null = { fg = u.aqua },
    f_lsp_symbol_icon_Number = { fg = u.orange },
    f_lsp_symbol_icon_Object = { fg = u.brightPurple },
    f_lsp_symbol_icon_Operator = { fg = u.fg1 },
    f_lsp_symbol_icon_Package = { fg = u.green },
    f_lsp_symbol_icon_Property = { fg = u.red },
    f_lsp_symbol_icon_Reference = { fg = u.fg1 },
    f_lsp_symbol_icon_Snippet = { fg = u.red },
    f_lsp_symbol_icon_String = { fg = u.green },
    f_lsp_symbol_icon_Struct = { fg = u.brightPurple },
    f_lsp_symbol_icon_Structure = { fg = u.brightPurple },
    f_lsp_symbol_icon_Text = { fg = u.green },
    f_lsp_symbol_icon_Type = { fg = u.yellow },
    f_lsp_symbol_icon_TypeParameter = { fg = u.red },
    f_lsp_symbol_icon_Unit = { fg = u.brightPurple },
    f_lsp_symbol_icon_Value = { fg = u.aqua },
    f_lsp_symbol_icon_Variable = { fg = u.brightPurple },
    f_lsp_symbol_sep = { fg = u.bg4 },
    f_lsp_symbol_text = { fg = u.fg2 },

    ---message
    f_um_search_count = { fg = u.yellow },

    ---notepad
    f_np_title = { link = "f_pk_finder_title" },

    ---notify
    -- stylua: ignore start
    f_un_border_trace       = { fg = u.fg2,     bg = t and u.bg0 or c.none },
    f_un_border_debug       = { fg = u.green,   bg = t and u.bg0 or c.none },
    f_un_border_info        = { fg = u.blue,    bg = t and u.bg0 or c.none },
    f_un_border_warn        = { fg = u.yellow,  bg = t and u.bg0 or c.none },
    f_un_border_error       = { fg = u.red,     bg = t and u.bg0 or c.none },
    f_un_icon_trace         = { fg = u.fg2,     bg = c.none },
    f_un_icon_debug         = { fg = u.green,   bg = c.none },
    f_un_icon_info          = { fg = u.blue,    bg = c.none },
    f_un_icon_warn          = { fg = u.yellow,  bg = c.none },
    f_un_icon_error         = { fg = u.red,     bg = c.none },
    f_un_level_trace        = { fg = u.fg2,     bg = c.none },
    f_un_level_debug        = { fg = u.green,   bg = c.none },
    f_un_level_info         = { fg = u.blue,    bg = c.none },
    f_un_level_warn         = { fg = u.yellow,  bg = c.none },
    f_un_level_error        = { fg = u.red,     bg = c.none },
    f_un_normal_trace       = { fg = u.fg2,     bg = t and u.bg0 or c.none },
    f_un_normal_debug       = { fg = u.fg2,     bg = t and u.bg0 or c.none },
    f_un_normal_info        = { fg = u.fg2,     bg = t and u.bg0 or c.none },
    f_un_normal_warn        = { fg = u.fg2,     bg = t and u.bg0 or c.none },
    f_un_normal_error       = { fg = u.fg2,     bg = t and u.bg0 or c.none },
    f_un_title_trace        = { fg = u.fg2,     bg = c.none },
    f_un_title_debug        = { fg = u.green,   bg = c.none },
    f_un_title_info         = { fg = u.blue,    bg = c.none },
    f_un_title_warn         = { fg = u.yellow,  bg = c.none },
    f_un_title_error        = { fg = u.red,     bg = c.none },
    f_un_winbar_trace       = { fg = u.fg2,     bg = u.bg0, sp = u.bg2,    bold = true, underline = true },
    f_un_winbar_debug       = { fg = u.green,   bg = u.bg0, sp = u.green,  bold = true, underline = true },
    f_un_winbar_info        = { fg = u.blue,    bg = u.bg0, sp = u.blue,   bold = true, underline = true },
    f_un_winbar_warn        = { fg = u.yellow,  bg = u.bg0, sp = u.yellow, bold = true, underline = true },
    f_un_winbar_error       = { fg = u.red,     bg = u.bg0, sp = u.red,    bold = true, underline = true },
    f_un_winbar_like_trace  = { fg = u.fg2,     bg = u.bg0, sp = u.bg2,    bold = true },
    f_un_winbar_like_debug  = { fg = u.green,   bg = u.bg0, sp = u.green,  bold = true },
    f_un_winbar_like_info   = { fg = u.blue,    bg = u.bg0, sp = u.blue,   bold = true },
    f_un_winbar_like_warn   = { fg = u.yellow,  bg = u.bg0, sp = u.yellow, bold = true },
    f_un_winbar_like_error  = { fg = u.red,     bg = u.bg0, sp = u.red,    bold = true },
    -- stylua: ignore end

    ---picker
    f_pk_finder_normal = { fg = u.fg1, bg = bg_pane },
    f_pk_finder_title = { link = t and "ms_b_bg0" or "ms_b_none" },
    f_pk_finder_prompt = { fg = u.red, bg = bg_pane },
    f_pk_replacer_prompt = { fg = u.brightBlue, bg = bg_pane },
    f_pk_matches = { fg = u.pink, bold = true, italic = true },
    f_pk_preview_current = { bg = u.bg2 },
    f_pk_preview_normal = { bg = bg_pane },
    f_pk_preview_title = { fg = u.green, bg = bg_pane, bold = true },
    f_pk_result_current = { bg = u.bg3 },
    f_pk_result_normal = { bg = bg_pane },
    f_pk_sign_line_current = { bg = u.bg3 },
    f_pk_sign_line_present = { fg = u.pink, bg = c.none, bold = true },
    f_pk_sign_line_present_current = { fg = u.pink, bg = u.bg3, bold = true },
    f_pk_sign_line_selected = { fg = u.purple, bg = c.none },
    f_pk_sign_line_selected_current = { fg = u.purple, bg = u.bg3 },

    ---popupmenu
    f_up_normal = { fg = u.fg2, bg = bg_pane },
    f_up_border = { link = t and "ms_b_bg0" or "ms_b_none" },
    f_up_selected = { fg = u.bg1, bg = u.blue, bold = true, italic = true },

    ---render-markdown
    f_md_bullet = { fg = c.tokenPunctuationDefinitionListBeginMarkdown },
    f_md_callout_error = { fg = c.accentRed, bold = true },
    f_md_callout_hint = { fg = c.accentAqua },
    f_md_callout_info = { fg = c.textLink_foreground },
    f_md_callout_progress = { fg = c.accentPurple, bold = true },
    f_md_callout_quote = { fg = c.text, bg = c.textBlockQuote_background },
    f_md_callout_success = { fg = c.success, bold = true },
    f_md_callout_warn = { fg = c.accentYellow, bold = true },
    f_md_code = { bg = c.textCodeBlock_background },
    f_md_code_border = { bg = c.textCodeBlock_background },
    f_md_code_fallback = { fg = c.textPreformat_foreground },
    f_md_code_header = { fg = c.textPreformat_foreground, bg = c.textCodeBlock_background },
    f_md_code_inline = { fg = c.tokenMarkupInlineRaw, bg = c.textPreformat_background },
    f_md_dash = { fg = c.tokenConstantCharacterEscape },
    f_md_heading_h1 = { fg = c.tokenControlFlowSpecialKeywords, bold = true },
    f_md_heading_h1_bg = { bg = cs.mix(c.base, c.tokenControlFlowSpecialKeywords, 20) },
    f_md_heading_h2 = { fg = c.tokenTypesDeclarationAndReferences, bold = true },
    f_md_heading_h2_bg = { bg = cs.mix(c.base, c.tokenTypesDeclarationAndReferences, 20) },
    f_md_heading_h3 = { fg = c.tokenFunctionDeclarations, bold = true },
    f_md_heading_h3_bg = { bg = cs.mix(c.base, c.tokenFunctionDeclarations, 20) },
    f_md_heading_h4 = { fg = c.tokenConstantsAndEnums, bold = true },
    f_md_heading_h4_bg = { bg = cs.mix(c.base, c.tokenConstantsAndEnums, 20) },
    f_md_heading_h5 = { fg = c.tokenVariableAndParameterName, bold = true },
    f_md_heading_h5_bg = { bg = cs.mix(c.base, c.tokenVariableAndParameterName, 20) },
    f_md_heading_h6 = { fg = c.tokenConstantNumeric, bold = true },
    f_md_heading_h6_bg = { bg = cs.mix(c.base, c.tokenConstantNumeric, 20) },
    f_md_link = { fg = c.textLink_foreground, underline = true },
    f_md_link_wiki = { fg = c.textLink_activeForeground, italic = true },
    f_md_quote = { fg = c.text, bg = c.textBlockQuote_background },
    f_md_table_filler = { link = "Conceal" },
    f_md_table_head = { fg = c.tokenTypesDeclarationAndReferences, bold = true },
    f_md_table_row = { fg = c.tokenString },
    f_md_task_open = { fg = u.fg3 },
    f_md_task_done = { fg = c.success, bold = true },
    f_md_task_question = { fg = c.accentRed, bold = true },
    f_md_task_next = { fg = c.textLink_foreground, bold = true },
    f_md_task_cancelled = { fg = u.fg4, italic = true },
    f_md_task_cancelled_text = { fg = u.fg4, italic = true, strikethrough = true },
    f_md_task_important = { fg = c.tokenControlFlowSpecialKeywords, bold = true },
    f_md_task_favorite = { fg = c.tokenConstantCharacterEscape, bold = true },
    f_md_text_inline_highlight = { fg = c.base, bg = cs.mix(c.base, c.tokenFunctionDeclarations, 50) },

    ---search
    f_us_input_normal = { fg = u.fg1, bg = bg },
    f_us_input_prompt = { fg = u.red, bg = bg },
    f_us_input_title = { link = t and "ms_b_bg0" or "ms_b_none" },
    f_us_main_bg = { bg = bg_pane },
    f_us_main_current = { bg = u.bg3 },
    f_us_main_match = { fg = u.blue },
    f_us_main_match_lnum = { fg = u.fg4 },
    f_us_main_present = { fg = u.blue, bg = c.none },
    f_us_main_present_cur = { fg = u.blue, bg = u.bg3 },
    f_us_main_normal = { bg = bg_pane },
    f_us_main_replace = { fg = u.green },
    f_us_main_search = { fg = u.red, strikethrough = true },
    f_us_preview_current = { bg = u.bg2 },
    f_us_preview_error = { fg = u.red, bold = true },
    f_us_preview_normal = { bg = bg_pane },
    f_us_preview_search = { fg = u.fg1, bg = u.diffDel, strikethrough = true },
    f_us_preview_search_cur = { fg = u.bg1, bg = u.red, bold = true, strikethrough = true },
    f_us_preview_replace = { fg = u.bg1, bg = u.diffAdd },
    f_us_preview_replace_cur = { fg = u.bg1, bg = u.green, bold = true },
    f_us_preview_title = { fg = u.green, bg = bg, bold = true },
    f_us_match = { fg = u.bg1, bg = u.yellow },
    f_us_match_cur = { fg = u.bg1, bg = u.red, bold = true, underline = true },

    ---search & replace
    f_sr_error = { fg = u.red, bold = true },
    f_sr_match = { fg = u.bg1, bg = u.yellow },
    f_sr_match_cur = { fg = u.bg1, bg = u.red, bold = true, underline = true },
    f_sr_search = { fg = u.fg1, bg = u.diffDel, strikethrough = true },
    f_sr_search_cur = { fg = u.bg1, bg = u.red, bold = true, strikethrough = true },
    f_sr_replace = { fg = u.fg1, bg = u.diffAdd },
    f_sr_replace_cur = { fg = u.bg1, bg = u.brightGreen, bold = true },

    ---searcher
    f_ss_matches = { fg = u.pink, bold = true, italic = true },
    f_ss_search = { fg = u.red, bold = true, italic = true, strikethrough = true },
    f_ss_replace = { fg = u.green, bold = true, italic = true },

    ---select codeaction
    f_us_codeaction_order = { fg = u.red, bg = c.none },
    f_us_codeaction_content = { fg = u.fg1, bg = c.none },
    f_us_codeaction_client_name = { fg = u.fg4, bg = c.none },

    ---signs
    fs_input_prompt = { fg = u.red, bg = bg },
    fs_main_current = { bg = u.bg3 },
    fs_main_present = { fg = u.blue, bg = c.none },
    fs_main_present_cur = { fg = u.blue, bg = u.bg3 },
    fs_main_selected = { fg = u.purple, bg = c.none },
    fs_main_selected_cur = { fg = u.purple, bg = u.bg3 },

    ---terminal
    f_us_terminal_bg = { bg = u.bg0 },
    f_us_terminal_current = { bg = u.bg2 },

    ---textarea
    f_ut_current = { bg = u.bg3 },
    f_ut_normal = { bg = bg_pane },

    ---treeview
    f_utw_indent = { fg = u.bg2 },
    f_utw_indent_float = { fg = u.bg4 },

    ---trailspace
    f_ux_trailspace = { bg = cs.mix(u.bg0, u.red, 60) },

    ---virtcolumn
    h_virtcolumn_1 = { fg = cs.mix(u.bg0, u.yellow, 20) },
    h_virtcolumn_2 = { fg = cs.mix(u.bg0, u.red, 25) },

    ---vim options
    f_us_vo_name = { fg = u.fg1 },
    f_us_vo_type = { fg = u.orange },
    f_us_vo_scope = { fg = u.red, bold = true },
    f_us_vo_value = { fg = u.fg3 },

    ---winsep
    f_winsep_border = {},
    f_winsep_normal = { link = "ms_none" },
    f_winsep_title = {},
  }
end

return M
