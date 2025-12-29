---@class ark.theme.hlgroup.widget
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local md = string.format("ark.theme.hlgroup.%s.widget", context.scheme.theme) ---@type string
  local ok, mod = pcall(require, md)
  if ok and mod then
    return mod.gen_hlgroup_map(context)
  end

  return M.default_gen_hlgroup_map(context)
end

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.default_gen_hlgroup_map(context)
  local cs = stl.color
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local t = context.transparency ---@type boolean

  local bg = t and u.none or u.bg0 ---@type string
  local bg_pane = t and u.bg0 or u.none ---@type string

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
    f_transparent = { bg = u.none },
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

    ---dim
    f_dim = { fg = u.fg4 },

    ---matched pairs
    f_matched_pairs_0 = { fg = u.green, bg = u.bg4, bold = true, italic = true },
    f_matched_pairs_1 = { fg = cs.mix(u.bg0, u.brightPurple, 90) },
    f_matched_pairs_2 = { fg = cs.mix(u.bg0, u.brightBlue, 90) },
    f_matched_pairs_3 = { fg = cs.mix(u.bg0, u.brightYellow, 90) },
    f_matched_pairs_4 = { fg = cs.mix(u.bg0, u.brightOrange, 90) },
    f_matched_pairs_5 = { fg = cs.mix(u.bg0, u.brightAqua, 90) },
    f_matched_pairs_6 = { fg = cs.mix(u.bg0, u.brightGreen, 90) },
    f_unmatched_pairs = { fg = u.red, italic = true },

    ---hipatterns
    f_hipattern_error = { fg = u.bg0, bg = u.red, bold = true, italic = true, underline = true },
    f_hipattern_warn = { fg = u.bg0, bg = u.yellow, bold = true, italic = true, underline = true },
    f_hipattern_todo = { fg = u.bg0, bg = u.purple, bold = true, italic = true, underline = true },
    f_hipattern_info = { fg = u.bg0, bg = u.blue, bold = true, italic = true, underline = true },
    f_hipattern_success = { fg = u.bg0, bg = u.green, bold = true, italic = true, underline = true },
    f_hipattern_hint = { fg = u.bg0, bg = u.aqua, bold = true, italic = true, underline = true },
    f_hipattern_quote = { fg = u.bg0, bg = u.fg3, bold = true, italic = true, underline = true },

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

    ---lsp
    f_lsp_diagnostic_error = { fg = u.red },
    f_lsp_diagnostic_error_cl = { fg = u.red, bg = u.bg3 },
    f_lsp_diagnostic_error_clb = { fg = u.red, bg = u.bg2 },
    f_lsp_diagnostic_warn = { fg = u.yellow },
    f_lsp_diagnostic_warn_cl = { fg = u.yellow, bg = u.bg3 },
    f_lsp_diagnostic_warn_clb = { fg = u.yellow, bg = u.bg2 },
    f_lsp_diagnostic_hint = { fg = u.purple },
    f_lsp_diagnostic_hint_cl = { fg = u.purple, bg = u.bg3 },
    f_lsp_diagnostic_hint_clb = { fg = u.purple, bg = u.bg2 },
    f_lsp_diagnostic_info = { fg = u.green },
    f_lsp_diagnostic_info_cl = { fg = u.green, bg = u.bg3 },
    f_lsp_diagnostic_info_clb = { fg = u.green, bg = u.bg2 },

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
    f_np_cursorline = { bg = u.bg2 },
    f_np_normal = { bg = bg_pane },
    f_np_title = { link = "m_pk_finder_title" },

    ---notify
    -- stylua: ignore start
    f_un_border_trace       = { fg = u.fg2,     bg = t and u.bg0 or u.none },
    f_un_border_debug       = { fg = u.green,   bg = t and u.bg0 or u.none },
    f_un_border_info        = { fg = u.blue,    bg = t and u.bg0 or u.none },
    f_un_border_warn        = { fg = u.yellow,  bg = t and u.bg0 or u.none },
    f_un_border_error       = { fg = u.red,     bg = t and u.bg0 or u.none },
    f_un_icon_trace         = { fg = u.fg2,     bg = u.none },
    f_un_icon_debug         = { fg = u.green,   bg = u.none },
    f_un_icon_info          = { fg = u.blue,    bg = u.none },
    f_un_icon_warn          = { fg = u.yellow,  bg = u.none },
    f_un_icon_error         = { fg = u.red,     bg = u.none },
    f_un_level_trace        = { fg = u.fg2,     bg = u.none },
    f_un_level_debug        = { fg = u.green,   bg = u.none },
    f_un_level_info         = { fg = u.blue,    bg = u.none },
    f_un_level_warn         = { fg = u.yellow,  bg = u.none },
    f_un_level_error        = { fg = u.red,     bg = u.none },
    f_un_normal_trace       = { fg = u.fg2,     bg = t and u.bg0 or u.none },
    f_un_normal_debug       = { fg = u.fg2,     bg = t and u.bg0 or u.none },
    f_un_normal_info        = { fg = u.fg2,     bg = t and u.bg0 or u.none },
    f_un_normal_warn        = { fg = u.fg2,     bg = t and u.bg0 or u.none },
    f_un_normal_error       = { fg = u.fg2,     bg = t and u.bg0 or u.none },
    f_un_title_trace        = { fg = u.fg2,     bg = u.none },
    f_un_title_debug        = { fg = u.green,   bg = u.none },
    f_un_title_info         = { fg = u.blue,    bg = u.none },
    f_un_title_warn         = { fg = u.yellow,  bg = u.none },
    f_un_title_error        = { fg = u.red,     bg = u.none },
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

    ---popupmenu
    f_up_normal = { fg = u.fg2, bg = bg_pane },
    f_up_border = { link = t and "ms_b_bg0" or "ms_b_none" },
    f_up_selected = { fg = u.bg1, bg = u.blue, bold = true, italic = true },

    ---render-markdown
    f_md_bullet = { fg = u.fg4 },
    f_md_callout_error = { fg = u.red, bold = true },
    f_md_callout_hint = { fg = u.aqua },
    f_md_callout_info = { fg = u.blue },
    f_md_callout_progress = { fg = u.aqua, bold = true },
    f_md_callout_quote = { fg = u.fg1, bg = u.bg2 },
    f_md_callout_success = { fg = u.green, bold = true },
    f_md_callout_warn = { fg = u.yellow, bold = true },
    f_md_code = { bg = u.bg2 },
    f_md_code_border = { fg = u.aqua, bg = u.bg2 },
    f_md_code_fallback = { fg = u.fg4 },
    f_md_code_header = { fg = u.purple, bg = u.bg2 },
    f_md_code_inline = { fg = u.orange, bg = u.bg4 },
    f_md_dash = { fg = u.orange },
    f_md_heading_h1 = { fg = u.purple, bold = true },
    f_md_heading_h1_bg = { bg = cs.mix(u.bg0, u.purple, 15) },
    f_md_heading_h2 = { fg = u.aqua, bold = true },
    f_md_heading_h2_bg = { bg = cs.mix(u.bg0, u.aqua, 15) },
    f_md_heading_h3 = { fg = u.orange, bold = true },
    f_md_heading_h3_bg = { bg = cs.mix(u.bg0, u.orange, 15) },
    f_md_heading_h4 = { fg = u.yellow, bold = true },
    f_md_heading_h4_bg = { bg = cs.mix(u.bg0, u.yellow, 15) },
    f_md_heading_h5 = { fg = u.blue, bold = true },
    f_md_heading_h5_bg = { bg = cs.mix(u.bg0, u.blue, 15) },
    f_md_heading_h6 = { fg = u.green, bold = true },
    f_md_heading_h6_bg = { bg = cs.mix(u.bg0, u.green, 15) },
    f_md_link = { fg = u.aqua, underline = true },
    f_md_link_wiki = { fg = u.aqua, italic = true },
    f_md_quote = { fg = u.fg1, bg = u.bg2 },
    f_md_table_filler = { link = "Conceal" },
    f_md_table_head = { fg = u.purple, bold = true },
    f_md_table_row = { fg = u.orange },
    f_md_task_open = { fg = u.fg3 },
    f_md_task_done = { fg = u.green, bold = true },
    f_md_task_question = { fg = u.red, bold = true },
    f_md_task_next = { fg = u.blue, bold = true },
    f_md_task_cancelled = { fg = u.bg4, italic = true },
    f_md_task_cancelled_text = { fg = u.bg4, italic = true, strikethrough = true },
    f_md_task_important = { fg = u.purple, bold = true },
    f_md_task_favorite = { fg = cs.mix(u.yellow, u.orange, 60), bold = true },
    f_md_text_inline_highlight = { fg = u.bg0, bg = cs.mix(u.bg0, u.yellow, 45) },

    ---signs
    fs_input_prompt = { fg = u.red, bg = bg },
    fs_main_current = { bg = u.bg3 },
    fs_main_present = { fg = u.blue, bg = u.none },
    fs_main_present_cur = { fg = u.blue, bg = u.bg3 },
    fs_main_selected = { fg = u.purple, bg = u.none },
    fs_main_selected_cur = { fg = u.purple, bg = u.bg3 },

    ---textarea
    f_ut_current = { bg = u.bg3 },
    f_ut_normal = { bg = bg_pane },

    ---treeview
    f_utw_indent = { fg = u.bg2 },
    f_utw_indent_float = { fg = u.bg4 },

    ---trailspace
    f_ux_trailspace = { bg = cs.mix(u.bg0, u.red, 60) },

    ---virtcolumn
    h_virtcolumn_1 = { fg = cs.mix(u.bg0, u.pink, 30) },
    h_virtcolumn_2 = { fg = cs.mix(u.bg0, u.red, 30) },

    ---winsep
    f_winsep_border = {},
    f_winsep_normal = { link = "ms_none" },
    f_winsep_title = {},

    ---maximize
    f_maximize_float_normal = { fg = u.fg1, bg = u.bg0 },
    f_maximize_float_border = { fg = u.bg4, bg = u.bg0 },
    f_maximize_normal = { fg = u.fg1, bg = u.bg0 },
  }
end

return M
