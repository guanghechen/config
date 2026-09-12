---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.nvimbar.rosepine" ---@type string

---@class dot.theme.hlgroup.nvimbar.rosepine
local M = {}

---@param context                       stl.t.theme.IContext
---@return dot.theme.hlgroup.nvimbar.IHlgroupMap
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette.rosepine ---@type stl.t.theme.IRosepinePalette
  local t = context.transparency ---@type boolean
  local bg_bufc = t and c.none or c.base ---@type string
  local bg_pos = c.overlay ---@type string

  local bgs = {
    f_sl = c.none,
    f_tl = c.none,
    f_wl = c.none,
  }

  ---@type table<string, stl.t.theme.IHlgroup>
  local hlgroup_map = {
    bg = { fg = "bg_bar", bg = "bg_bar" },
    text = { fg = c.subtle, bg = "bg_bar" },

    ------------------------------------------------------------------------------------------------

    ---! ai
    ai_status_icon = { fg = c.pine, bg = "bg_bar" },
    ai_status_text = { fg = c.subtle, bg = "bg_bar" },

    ---! buf
    buf = { fg = c.highlightHigh, bg = "bg_bar" },
    buf_disambiguation = { fg = c.subtle, bg = "bg_bar", italic = true },
    buf_indicator = { fg = c.muted, bg = "bg_bar", bold = true },
    buf_mod = { fg = c.muted, bg = "bg_bar" },
    buf_omitter = { fg = c.foam, bg = "bg_bar" },
    buf_omitter_sep = { fg = c.highlightHigh, bg = "bg_bar" },
    buf_pinned = { fg = c.muted, bg = "bg_bar" },
    buf_order = { fg = c.muted, bg = "bg_bar" },
    buf_text = { fg = c.muted, bg = "bg_bar" },
    bufc = { fg = c.subtle, bg = bg_bufc },
    bufc_disambiguation = { link = t and "ms_i_none" or "ms_i_bg0" },
    bufc_indicator = { link = t and "ms_b_none" or "ms_b_bg0" },
    bufc_mod = { fg = c.pine, bg = bg_bufc },
    bufc_pinned = { fg = c.text, bg = bg_bufc },
    bufc_order = { link = t and "ms_bi_none" or "ms_bi_bg0" },
    bufc_text = { link = t and "ms_bi_none" or "ms_bi_bg0" },
    bufc_error = { fg = c.love, bg = bg_bufc, bold = true, italic = true },
    bufc_warn = { fg = c.gold, bg = bg_bufc, bold = true, italic = true },
    bufc_hint = { fg = c.iris, bg = bg_bufc, bold = true, italic = true },
    bufc_info = { fg = c.foam, bg = bg_bufc, bold = true, italic = true },

    ---! cwd
    cwd_text = { link = "mf_b_bg0" },
    cwd_sep = { link = "ms_b_none" },

    ---! devmode
    devmode_text = { fg = c.base, bg = c.gold, bold = true },
    devmode_render_count_text = { fg = c.base, bg = c.gold, bold = true },
    devmode_render_count_sep = { fg = c.gold, bg = c.none, bold = true },

    ---! dir
    dir_path_blur_sep = { fg = c.muted, bg = "bg_bar" },
    dir_path_blur_text = { fg = c.subtle, bg = "bg_bar" },
    dir_path_focus_sep = { fg = c.text, bg = "bg_bar", bold = true },
    dir_path_focus_text = { fg = c.foam, bg = "bg_bar", bold = true },
    dir_path_prominent_icon = { fg = c.base, bg = c.rose, bold = true },
    dir_path_prominent_text = { fg = c.base, bg = c.rose, bold = true },

    ---! file
    file_encoding_text = { fg = c.subtle, bg = "bg_bar" },
    file_format_text = { fg = c.subtle, bg = "bg_bar" },
    file_indent_text = { fg = c.subtle, bg = "bg_bar" },
    file_name_text = { fg = c.subtle, bg = "bg_bar" },
    file_name_text_active = { link = "ms_b_none" },
    file_path_text = { fg = c.subtle, bg = "bg_bar" },
    file_readonly = { fg = c.gold, bg = "bg_bar" },
    file_size_text = { fg = c.subtle, bg = "bg_bar" },
    file_status_text = { fg = c.subtle, bg = "bg_bar" },
    file_type_text = { fg = c.subtle, bg = "bg_bar" },

    ---! git
    git_branch_sep = { fg = bg_pos, bg = "bg_bar" },
    git_branch_text = { fg = c.text, bg = bg_pos, bold = true },

    ---! host
    host_username_sep = { link = "mf_b_bg0" },
    host_username_text = { link = "ms_b_none" },

    ---! lint
    lint_icon_active = { fg = c.pine, bg = "bg_bar" },
    lint_icon_inactive = { fg = c.highlightHigh, bg = "bg_bar" },
    lint_text = { fg = c.subtle, bg = "bg_bar" },

    ---! lsp
    lsp_client_text = { fg = c.subtle, bg = "bg_bar" },
    lsp_icon_basedpyright = { fg = c.gold, bg = "bg_bar" },
    lsp_icon_bashls = { fg = c.pine, bg = "bg_bar" },
    lsp_icon_biome = { fg = c.foam, bg = "bg_bar" },
    lsp_icon_cssls = { fg = c.foam, bg = "bg_bar" },
    lsp_icon_docker_compose_language_service = { fg = c.rose, bg = "bg_bar" },
    lsp_icon_dockerls = { fg = c.foam, bg = "bg_bar" },
    lsp_icon_emmet_language_server = { fg = c.gold, bg = "bg_bar" },
    lsp_icon_eslint = { fg = c.iris, bg = "bg_bar" },
    lsp_icon_html = { fg = c.gold, bg = "bg_bar" },
    lsp_icon_jsonls = { fg = c.gold, bg = "bg_bar" },
    lsp_icon_lua_ls = { fg = c.foam, bg = "bg_bar" },
    lsp_icon_roslyn_ls = { fg = c.pine, bg = "bg_bar" },
    lsp_icon_ruff = { fg = c.pine, bg = "bg_bar" },
    lsp_icon_rust_analyzer = { fg = c.gold, bg = "bg_bar" },
    lsp_icon_stylua = { fg = c.rose, bg = "bg_bar" },
    lsp_icon_tailwindcss = { fg = c.rose, bg = "bg_bar" },
    lsp_icon_taplo = { fg = c.gold, bg = "bg_bar" },
    lsp_icon_vtsls = { fg = c.foam, bg = "bg_bar" },
    lsp_icon_yamlls = { fg = c.gold, bg = "bg_bar" },
    lsp_diagnostics_error = { fg = c.love, bg = "bg_bar" },
    lsp_diagnostics_warn = { fg = c.gold, bg = "bg_bar" },
    lsp_diagnostics_hint = { fg = c.iris, bg = "bg_bar" },
    lsp_diagnostics_info = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon = { fg = c.iris, bg = "bg_bar" },
    lsp_symbol_icon_Array = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_Boolean = { fg = c.rose, bg = "bg_bar" },
    lsp_symbol_icon_Class = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_Color = { fg = c.iris, bg = "bg_bar" },
    lsp_symbol_icon_Constant = { fg = c.gold, bg = "bg_bar" },
    lsp_symbol_icon_Constructor = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_Enum = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_EnumMember = { fg = c.gold, bg = "bg_bar" },
    lsp_symbol_icon_Event = { fg = c.love, bg = "bg_bar" },
    lsp_symbol_icon_Field = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_File = { fg = c.text, bg = "bg_bar" },
    lsp_symbol_icon_Folder = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_Function = { fg = c.rose, bg = "bg_bar" },
    lsp_symbol_icon_Identifier = { fg = c.text, bg = "bg_bar" },
    lsp_symbol_icon_Interface = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_Key = { fg = c.rose, bg = "bg_bar" },
    lsp_symbol_icon_Keyword = { fg = c.pine, bg = "bg_bar" },
    lsp_symbol_icon_Method = { fg = c.rose, bg = "bg_bar" },
    lsp_symbol_icon_Module = { fg = c.text, bg = "bg_bar" },
    lsp_symbol_icon_Namespace = { fg = c.text, bg = "bg_bar" },
    lsp_symbol_icon_Null = { fg = c.iris, bg = "bg_bar" },
    lsp_symbol_icon_Number = { fg = c.gold, bg = "bg_bar" },
    lsp_symbol_icon_Object = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_Operator = { fg = c.subtle, bg = "bg_bar" },
    lsp_symbol_icon_Package = { fg = c.pine, bg = "bg_bar" },
    lsp_symbol_icon_Property = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_Reference = { fg = c.love, bg = "bg_bar" },
    lsp_symbol_icon_Snippet = { fg = c.iris, bg = "bg_bar" },
    lsp_symbol_icon_String = { fg = c.gold, bg = "bg_bar" },
    lsp_symbol_icon_Struct = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_Structure = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_Text = { fg = c.text, bg = "bg_bar" },
    lsp_symbol_icon_Type = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_TypeParameter = { fg = c.foam, bg = "bg_bar" },
    lsp_symbol_icon_Unit = { fg = c.pine, bg = "bg_bar" },
    lsp_symbol_icon_Value = { fg = c.gold, bg = "bg_bar" },
    lsp_symbol_icon_Variable = { fg = c.text, bg = "bg_bar" },
    lsp_symbol_sep = { fg = c.subtle, bg = "bg_bar" },
    lsp_symbol_text = { fg = c.subtle, bg = "bg_bar" },

    ---! nvim
    nvim_mode_sep = { link = "ms_b_bg2" },
    nvim_mode_text = { link = "mf_b_bg0" },
    nvim_msg_command = { fg = c.rose, bg = "bg_bar" },
    nvim_msg_lsp = { fg = c.muted, bg = "bg_bar" },
    nvim_msg_mode = { fg = c.gold, bg = "bg_bar" },
    nvim_msg_transient = { fg = c.muted, bg = "bg_bar" },
    nvim_search_count = { fg = c.gold, bg = "bg_bar" },
    nvim_nr_sep = { fg = bg_pos, bg = c.base },
    nvim_nr_text = { fg = c.subtle, bg = bg_pos, bold = true },
    nvim_pid = { fg = c.muted, bg = "bg_bar" },
    nvim_pos_sep = { link = "ms_b_bg2" },
    nvim_pos_text = { link = "mf_b_bg0" },
    nvim_pos_bar_1 = { link = "ms_b_none" },
    nvim_pos_bar_2 = { link = "ms_b_none" },
    nvim_pos_bar_3 = { link = "ms_b_none" },
    nvim_pos_bar_4 = { link = "ms_b_none" },
    nvim_pos_bar_5 = { link = "ms_b_none" },
    nvim_pos_bar_6 = { link = "ms_b_none" },
    nvim_pos_bar_7 = { link = "ms_b_none" },
    nvim_pos_bar_8 = { link = "ms_b_none" },
    nvim_pos_bar_9 = { link = "ms_b_none" },
    nvim_tab_item = { fg = c.text, bg = "bg_bar" },
    nvim_tab_item_cur = { fg = c.love, bg = bg_bufc },
    nvim_tab_toggle = { fg = c.surface, bg = c.pine },
    nvim_tabtype_sep = { link = "ms_b_none" },
    nvim_tabtype_text = { link = "mf_b_bg0" },

    ---! explorer
    explorer_detached = { fg = c.love, bg = "bg_bar" },
    explorer_flag_aqua = { fg = c.base, bg = c.rose },
    explorer_flag_blue = { fg = c.base, bg = c.foam },
    explorer_flag_green = { fg = c.base, bg = c.pine },
    explorer_flag_grey = { fg = c.muted, bg = c.overlay },
    explorer_flag_orange = { fg = c.base, bg = c.gold },
    explorer_flag_purple = { fg = c.base, bg = c.iris },
    explorer_flag_red = { fg = c.base, bg = c.love },
    explorer_flag_yellow = { fg = c.base, bg = c.gold },
    explorer_path = { fg = c.rose, bg = "bg_bar", bold = true },
    explorer_path_detached = { fg = c.love, bg = "bg_bar", bold = true },

    ---! picker
    picker = { sp = c.rose, underline = true },
    picker_flag_grey = { fg = c.muted, bg = c.overlay, sp = c.rose, underline = true },
    picker_flag_red = { fg = c.base, bg = c.love, sp = c.rose, underline = true },
    picker_flag_green = { fg = c.base, bg = c.pine, sp = c.rose, underline = true },
    picker_flag_yellow = { fg = c.base, bg = c.gold, sp = c.rose, underline = true },
    picker_flag_blue = { fg = c.base, bg = c.foam, sp = c.rose, underline = true },
    picker_flag_purple = { fg = c.base, bg = c.iris, sp = c.rose, underline = true },
    picker_flag_aqua = { fg = c.base, bg = c.rose, sp = c.rose, underline = true },
    picker_flag_orange = { fg = c.base, bg = c.gold, sp = c.rose, underline = true },
    picker_result_limit = { fg = c.base, bg = c.gold, bold = true, sp = c.rose, underline = true },
    picker_result_pos_text = { fg = c.muted, bg = "bg_bar", sp = c.rose, underline = true },

    ---! python
    python_env_text = { fg = c.subtle, bg = "bg_bar" },

    ---! searcher
    searcher = { fg = c.rose, sp = c.rose, underline = true },

    ---! sidebar
    sidebar_blank = { fg = c.text, bg = "bg_bar" },
    sidebar_dim = { fg = c.muted, bg = "bg_bar" },
    sidebar_split = { fg = c.highlightHigh, bg = "bg_bar" },
    sidebar_pink = { fg = c.rose, bg = "bg_bar" },

    ---! flag (for diffview tabline)
    flag_off = { fg = c.muted, bg = c.overlay },
    flag_on = { fg = c.base, bg = c.foam },
    flag_viewtype = { fg = c.base, bg = c.iris },
    flag_layout = { fg = c.base, bg = c.rose },

    ---! notepad
    notepad_button = { fg = c.muted, bg = "bg_bar" },
    notepad_source = { fg = c.surface, bg = c.rose, bold = true },
    notepad_source_sep = { fg = c.rose, bg = "bg_bar" },
    notepad_name = { fg = c.text, bg = c.highlightMed },
    notepad_index = { fg = c.text, bg = c.highlightHigh },
    notepad_sep_left = { fg = c.highlightMed, bg = "bg_bar" },
    notepad_sep_middle = { fg = c.highlightHigh, bg = "bg_bar" },
    notepad_sep_right = { fg = c.highlightMed, bg = "bg_bar" },
    notepadc_name = { link = "mf_b_bg0" },
    notepadc_index = { link = "mf_b_bg0" },
    notepadc_sep_left = { link = "ms_b_none" },
    notepadc_sep_middle = { link = "mf_b_bg0" },
    notepadc_sep_right = { link = "ms_b_none" },

    ---! term
    term_button = { fg = c.text, bg = c.highlightHigh },
    term_index = { fg = c.text, bg = c.highlightHigh },
    term_name = { fg = c.text, bg = c.highlightMed },
    term_sep_left = { fg = c.highlightMed, bg = "bg_bar" },
    term_sep_right = { fg = c.highlightHigh, bg = "bg_bar" },
    termc_index = { link = "mf_b_bg0" },
    termc_name = { link = "mf_b_bg0" },
    termc_sep_left = { link = "ms_b_none" },
    termc_sep_middle = { link = "mf_b_bg0" },
    termc_sep_right = { link = "ms_b_none" },
  }

  local positions = { "f_sl", "f_tl", "f_wl" } ---@type stl.t.NvimbarPositionEnum[]

  local results = {} ---@type table<string, stl.t.theme.IHlgroup>
  for _, position in ipairs(positions) do
    for hlname, hlgroup in pairs(hlgroup_map) do
      results[position .. "_" .. hlname] = {
        fg = hlgroup.fg == "bg_bar" and bgs[position] or hlgroup.fg,
        bg = hlgroup.bg == "bg_bar" and bgs[position] or hlgroup.bg,
        sp = hlgroup.sp,
        bold = hlgroup.bold,
        italic = hlgroup.italic,
        link = hlgroup.link,
        reverse = hlgroup.reverse,
        strikethrough = hlgroup.strikethrough,
        undercurl = hlgroup.undercurl,
        underline = hlgroup.underline,
      }
    end
  end
  ---@cast results dot.theme.hlgroup.nvimbar.IHlgroupMap
  return results
end

return M
