---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.widget.rosepine" ---@type string

---@class dot.theme.hlgroup.widget.rosepine
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = stl.color
  local c = context.scheme.palette.rosepine ---@type stl.t.theme.IRosepinePalette
  local t = context.transparency ---@type boolean

  local bg = t and c.none or c.base ---@type string
  local bg_pane = t and c.base or c.none ---@type string

  -- Tint diff fills from the native palette, independent of window transparency.
  local diff_add = cs.mix(c.base, c.pine, 15)
  local diff_del = cs.mix(c.base, c.love, 15)
  local diff_add_inline = cs.mix(c.base, c.pine, 30)
  local diff_del_inline = cs.mix(c.base, c.love, 30)

  return {
    ---buffers
    f_buf_nr = { fg = c.muted },
    f_buf_filetype = { fg = c.muted },
    f_buf_filepath = { fg = c.text },

    ---cmdline
    f_uc_border = { link = "FloatActiveBorder" },
    f_uc_icon_command = { fg = c.rose, bg = bg },
    f_uc_icon_command_help = { fg = c.iris, bg = bg },
    f_uc_icon_command_lua = { fg = c.foam, bg = bg },
    f_uc_icon_search_forward = { fg = c.gold, bg = bg },
    f_uc_icon_search_backward = { fg = c.gold, bg = bg },
    f_uc_option = { fg = c.text, bg = c.surface },
    f_uc_option_current = { fg = c.base, bg = c.rose, bold = true },
    f_uc_type_lua = { fg = c.foam, bg = bg },

    ---common
    f_lnum_error = { fg = c.love },
    f_lnum_warn = { fg = c.gold },
    f_lnum_info = { fg = c.foam },
    f_lnum_hint = { fg = c.iris },
    f_transparent = { bg = c.none },
    -- Keep the badge background opaque when combined with NormalNC.
    f_fold_virt_text = { fg = c.overlay, bg = c.gold, italic = true, blend = 0 },
    f_fold_virt_text_inv = { fg = c.gold, bg = bg, italic = true },

    ---diff
    f_diff_add_left = { bg = diff_del },
    f_diff_add_right = { bg = diff_add },
    f_diff_del_left = { bg = diff_del },
    f_diff_del_right = { bg = diff_del },
    f_diff_mod_left = { bg = diff_del },
    f_diff_mod_right = { bg = diff_add },
    f_diff_word_left = { fg = c.text, bg = diff_del_inline },
    f_diff_word_right = { fg = c.text, bg = diff_add_inline },

    ---dim
    f_dim = { fg = c.muted },

    ---matched pairs
    f_matched_pairs_0 = { fg = c.text, bg = c.highlightMed, bold = true, italic = true },
    f_matched_pairs_1 = { fg = cs.mix(c.base, c.iris, 90) },
    f_matched_pairs_2 = { fg = cs.mix(c.base, c.foam, 90) },
    f_matched_pairs_3 = { fg = cs.mix(c.base, c.gold, 90) },
    f_matched_pairs_4 = { fg = cs.mix(c.base, c.love, 90) },
    f_matched_pairs_5 = { fg = cs.mix(c.base, c.rose, 90) },
    f_matched_pairs_6 = { fg = cs.mix(c.base, c.pine, 90) },
    f_unmatched_pairs = { fg = c.love, italic = true },

    ---hipatterns
    f_hipattern_error = { fg = c.base, bg = c.love, bold = true, italic = true, underline = true },
    f_hipattern_warn = { fg = c.base, bg = c.gold, bold = true, italic = true, underline = true },
    f_hipattern_todo = { fg = c.base, bg = c.iris, bold = true, italic = true, underline = true },
    f_hipattern_info = { fg = c.base, bg = c.foam, bold = true, italic = true, underline = true },
    f_hipattern_success = { fg = c.base, bg = c.pine, bold = true, italic = true, underline = true },
    f_hipattern_hint = { fg = c.base, bg = c.rose, bold = true, italic = true, underline = true },
    f_hipattern_quote = { fg = c.base, bg = c.muted, bold = true, italic = true, underline = true },

    ---indentline
    f_indentline_1 = { fg = cs.mix(c.base, c.love, 20) },
    f_indentline_2 = { fg = cs.mix(c.base, c.gold, 20) },
    f_indentline_3 = { fg = cs.mix(c.base, c.gold, 20) },
    f_indentline_4 = { fg = cs.mix(c.base, c.pine, 20) },
    f_indentline_5 = { fg = cs.mix(c.base, c.rose, 20) },
    f_indentline_6 = { fg = cs.mix(c.base, c.foam, 20) },
    f_indentline_7 = { fg = cs.mix(c.base, c.iris, 20) },

    ---indentscope
    f_indentscope_1 = { fg = cs.mix(c.base, c.love, 80), bold = true },
    f_indentscope_2 = { fg = cs.mix(c.base, c.gold, 80), bold = true },
    f_indentscope_3 = { fg = cs.mix(c.base, c.gold, 80), bold = true },
    f_indentscope_4 = { fg = cs.mix(c.base, c.pine, 80), bold = true },
    f_indentscope_5 = { fg = cs.mix(c.base, c.rose, 80), bold = true },
    f_indentscope_6 = { fg = cs.mix(c.base, c.foam, 80), bold = true },
    f_indentscope_7 = { fg = cs.mix(c.base, c.iris, 80), bold = true },

    ---lsp
    f_lsp_diagnostic_error = { fg = c.love },
    f_lsp_diagnostic_error_cl = { fg = c.love, bg = c.highlightMed },
    f_lsp_diagnostic_error_clb = { fg = c.love, bg = c.overlay },
    f_lsp_diagnostic_warn = { fg = c.gold },
    f_lsp_diagnostic_warn_cl = { fg = c.gold, bg = c.highlightMed },
    f_lsp_diagnostic_warn_clb = { fg = c.gold, bg = c.overlay },
    f_lsp_diagnostic_hint = { fg = c.iris },
    f_lsp_diagnostic_hint_cl = { fg = c.iris, bg = c.highlightMed },
    f_lsp_diagnostic_hint_clb = { fg = c.iris, bg = c.overlay },
    f_lsp_diagnostic_info = { fg = c.foam },
    f_lsp_diagnostic_info_cl = { fg = c.foam, bg = c.highlightMed },
    f_lsp_diagnostic_info_clb = { fg = c.foam, bg = c.overlay },

    ---lsp symbols
    f_lsp_symbol_icon = { fg = c.iris },
    f_lsp_symbol_icon_Array = { fg = c.foam },
    f_lsp_symbol_icon_Boolean = { fg = c.rose },
    f_lsp_symbol_icon_Class = { fg = c.foam },
    f_lsp_symbol_icon_Color = { fg = c.iris },
    f_lsp_symbol_icon_Constant = { fg = c.gold },
    f_lsp_symbol_icon_Constructor = { fg = c.foam },
    f_lsp_symbol_icon_Enum = { fg = c.foam },
    f_lsp_symbol_icon_EnumMember = { fg = c.gold },
    f_lsp_symbol_icon_Event = { fg = c.love },
    f_lsp_symbol_icon_Field = { fg = c.foam },
    f_lsp_symbol_icon_File = { fg = c.text },
    f_lsp_symbol_icon_Folder = { fg = c.foam },
    f_lsp_symbol_icon_Function = { fg = c.rose },
    f_lsp_symbol_icon_Identifier = { fg = c.text },
    f_lsp_symbol_icon_Interface = { fg = c.foam },
    f_lsp_symbol_icon_Key = { fg = c.rose },
    f_lsp_symbol_icon_Keyword = { fg = c.pine },
    f_lsp_symbol_icon_Method = { fg = c.rose },
    f_lsp_symbol_icon_Module = { fg = c.text },
    f_lsp_symbol_icon_Namespace = { fg = c.text },
    f_lsp_symbol_icon_Null = { fg = c.iris },
    f_lsp_symbol_icon_Number = { fg = c.gold },
    f_lsp_symbol_icon_Object = { fg = c.foam },
    f_lsp_symbol_icon_Operator = { fg = c.subtle },
    f_lsp_symbol_icon_Package = { fg = c.pine },
    f_lsp_symbol_icon_Property = { fg = c.foam },
    f_lsp_symbol_icon_Reference = { fg = c.love },
    f_lsp_symbol_icon_Snippet = { fg = c.iris },
    f_lsp_symbol_icon_String = { fg = c.gold },
    f_lsp_symbol_icon_Struct = { fg = c.foam },
    f_lsp_symbol_icon_Structure = { fg = c.foam },
    f_lsp_symbol_icon_Text = { fg = c.text },
    f_lsp_symbol_icon_Type = { fg = c.foam },
    f_lsp_symbol_icon_TypeParameter = { fg = c.foam },
    f_lsp_symbol_icon_Unit = { fg = c.pine },
    f_lsp_symbol_icon_Value = { fg = c.gold },
    f_lsp_symbol_icon_Variable = { fg = c.text },
    f_lsp_symbol_sep = { fg = c.highlightHigh },
    f_lsp_symbol_text = { fg = c.subtle },

    ---notepad
    f_np_cursorline = { bg = c.overlay },
    f_np_normal = { bg = bg_pane },
    f_np_title = { link = "m_pk_finder_title" },

    ---notify
    f_un_border_trace = { fg = c.subtle, bg = t and c.base or c.none },
    f_un_border_debug = { fg = c.pine, bg = t and c.base or c.none },
    f_un_border_info = { fg = c.foam, bg = t and c.base or c.none },
    f_un_border_warn = { fg = c.gold, bg = t and c.base or c.none },
    f_un_border_error = { fg = c.love, bg = t and c.base or c.none },
    f_un_icon_trace = { fg = c.subtle, bg = c.none },
    f_un_icon_debug = { fg = c.pine, bg = c.none },
    f_un_icon_info = { fg = c.foam, bg = c.none },
    f_un_icon_warn = { fg = c.gold, bg = c.none },
    f_un_icon_error = { fg = c.love, bg = c.none },
    f_un_level_trace = { fg = c.subtle, bg = c.none },
    f_un_level_debug = { fg = c.pine, bg = c.none },
    f_un_level_info = { fg = c.foam, bg = c.none },
    f_un_level_warn = { fg = c.gold, bg = c.none },
    f_un_level_error = { fg = c.love, bg = c.none },
    f_un_normal_trace = { fg = c.subtle, bg = t and c.base or c.none },
    f_un_normal_debug = { fg = c.subtle, bg = t and c.base or c.none },
    f_un_normal_info = { fg = c.subtle, bg = t and c.base or c.none },
    f_un_normal_warn = { fg = c.subtle, bg = t and c.base or c.none },
    f_un_normal_error = { fg = c.subtle, bg = t and c.base or c.none },
    f_un_title_trace = { fg = c.subtle, bg = c.none },
    f_un_title_debug = { fg = c.pine, bg = c.none },
    f_un_title_info = { fg = c.foam, bg = c.none },
    f_un_title_warn = { fg = c.gold, bg = c.none },
    f_un_title_error = { fg = c.love, bg = c.none },
    f_un_winbar_trace = { fg = c.subtle, bg = c.base, sp = c.overlay, bold = true, underline = true },
    f_un_winbar_debug = { fg = c.pine, bg = c.base, sp = c.pine, bold = true, underline = true },
    f_un_winbar_info = { fg = c.foam, bg = c.base, sp = c.foam, bold = true, underline = true },
    f_un_winbar_warn = { fg = c.gold, bg = c.base, sp = c.gold, bold = true, underline = true },
    f_un_winbar_error = { fg = c.love, bg = c.base, sp = c.love, bold = true, underline = true },
    f_un_winbar_like_trace = { fg = c.subtle, bg = c.base, sp = c.overlay, bold = true },
    f_un_winbar_like_debug = { fg = c.pine, bg = c.base, sp = c.pine, bold = true },
    f_un_winbar_like_info = { fg = c.foam, bg = c.base, sp = c.foam, bold = true },
    f_un_winbar_like_warn = { fg = c.gold, bg = c.base, sp = c.gold, bold = true },
    f_un_winbar_like_error = { fg = c.love, bg = c.base, sp = c.love, bold = true },

    ---popupmenu
    f_up_normal = { fg = c.subtle, bg = bg_pane },
    f_up_border = { link = t and "ms_b_bg0" or "ms_b_none" },
    f_up_selected = { fg = c.text, bg = c.highlightMed, bold = true, italic = true },

    ---render-markdown
    f_md_bullet = { fg = c.muted },
    f_md_callout_error = { fg = c.love, bold = true },
    f_md_callout_hint = { fg = c.rose },
    f_md_callout_info = { fg = c.foam },
    f_md_callout_progress = { fg = c.rose, bold = true },
    f_md_callout_quote = { fg = c.text, bg = c.overlay },
    f_md_callout_success = { fg = c.pine, bold = true },
    f_md_callout_warn = { fg = c.gold, bold = true },
    f_md_code = { bg = c.surface },
    f_md_code_border = { fg = c.muted, bg = c.surface },
    f_md_code_fallback = { fg = c.text },
    f_md_code_header = { fg = c.rose, bg = c.surface },
    f_md_code_inline = { fg = c.gold, bg = c.highlightLow },
    f_md_dash = { fg = c.gold },
    f_md_titled_separator = { fg = c.iris, bold = true },
    f_md_heading_h1 = { fg = c.rose, bold = true },
    f_md_heading_h1_bg = { bg = cs.mix(c.base, c.rose, 15) },
    f_md_heading_h2 = { fg = c.foam, bold = true },
    f_md_heading_h2_bg = { bg = cs.mix(c.base, c.foam, 15) },
    f_md_heading_h3 = { fg = c.iris, bold = true },
    f_md_heading_h3_bg = { bg = cs.mix(c.base, c.iris, 15) },
    f_md_heading_h4 = { fg = c.gold, bold = true },
    f_md_heading_h4_bg = { bg = cs.mix(c.base, c.gold, 15) },
    f_md_heading_h5 = { fg = c.pine, bold = true },
    f_md_heading_h5_bg = { bg = cs.mix(c.base, c.pine, 15) },
    f_md_heading_h6 = { fg = c.foam, bold = true },
    f_md_heading_h6_bg = { bg = cs.mix(c.base, c.foam, 15) },
    f_md_link = { fg = c.rose, underline = true },
    f_md_link_wiki = { fg = c.rose, italic = true },
    f_md_quote = { fg = c.text, bg = c.overlay },
    f_md_table_filler = { link = "Conceal" },
    f_md_table_head = { fg = c.iris, bold = true },
    f_md_table_row = { fg = c.gold },
    f_md_task_open = { fg = c.muted },
    f_md_task_done = { fg = c.pine, bold = true },
    f_md_task_question = { fg = c.love, bold = true },
    f_md_task_next = { fg = c.foam, bold = true },
    f_md_task_cancelled = { fg = c.muted, italic = true },
    f_md_task_cancelled_text = { fg = c.muted, italic = true, strikethrough = true },
    f_md_task_important = { fg = c.iris, bold = true },
    f_md_task_favorite = { fg = c.gold, bold = true },
    f_md_text_inline_highlight = { fg = c.text, bg = c.highlightMed },

    ---signs
    fs_input_prompt = { fg = c.love, bg = bg },
    fs_main_current = { bg = c.highlightMed },
    fs_main_present = { fg = c.foam, bg = c.none },
    fs_main_present_cur = { fg = c.foam, bg = c.highlightMed },
    fs_main_selected = { fg = c.iris, bg = c.none },
    fs_main_selected_cur = { fg = c.iris, bg = c.highlightMed },

    ---textarea
    f_ut_current = { bg = c.highlightMed },
    f_ut_normal = { bg = bg_pane },

    ---treeview
    f_utw_indent = { fg = c.overlay },
    f_utw_indent_float = { fg = c.highlightHigh },

    ---trailspace
    f_ux_trailspace = { bg = cs.mix(c.base, c.love, 60) },

    ---virtcolumn
    h_virtcolumn_1 = { fg = cs.mix(c.base, c.rose, 30) },
    h_virtcolumn_2 = { fg = cs.mix(c.base, c.love, 30) },

    ---winsep
    f_winsep_border = {},
    f_winsep_normal = { link = "ms_none" },
    f_winsep_title = {},

    ---maximize
    f_maximize_float_normal = { fg = c.text, bg = c.base },
    f_maximize_float_border = { fg = c.highlightHigh, bg = c.base },
    f_maximize_normal = { fg = c.text, bg = c.base },
  }
end

return M
