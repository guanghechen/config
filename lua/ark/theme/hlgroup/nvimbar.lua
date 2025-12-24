---@class ark.theme.hlgroup.nvimbar
local M = {}

---@param context                       ark.t.theme.IContext
---@return ark.theme.hlgroup.nvimbar
function M.gen_hlgroup_map(context)
  local cs = ark.color
  local c = context.scheme.palette.unified ---@type ark.t.theme.IUnifiedPalette
  local t = context.transparency ---@type boolean
  local bg_bufc = t and c.none or c.bg0 ---@type string
  local bg_pos = c.bg2 ---@type string

  local bgs = {
    f_sl = c.none,
    f_tl = c.none,
    f_wl = c.none,
  }

  ---@type table<string, ark.t.theme.IHlgroup>
  local hlgroup_map = {
    bg = { fg = "bg_bar", bg = "bg_bar" },
    text = { fg = c.fg2, bg = "bg_bar" },

    ------------------------------------------------------------------------------------------------

    ---! ai
    ai_copilot_icon_connected = { fg = c.brightGreen, bg = "bg_bar" },
    ai_copilot_icon_busy = { fg = c.brightYellow, bg = "bg_bar" },
    ai_copilot_icon_error = { fg = c.brightRed, bg = "bg_bar" },
    ai_copilot_status_Error = { fg = c.brightRed, bg = "bg_bar" },
    ai_copilot_status_Stopped = { fg = c.red, bg = "bg_bar" },
    ai_copilot_status_Busy = { fg = c.brightYellow, bg = "bg_bar" },
    ai_status_icon = { fg = c.brightGreen, bg = "bg_bar" },
    ai_status_text = { fg = c.fg2, bg = "bg_bar" },

    ---! buf
    buf = { fg = c.bg4, bg = "bg_bar" },
    buf_disambiguation = { fg = c.grey, bg = "bg_bar", italic = true },
    buf_indicator = { fg = c.fg4, bg = "bg_bar", bold = true },
    buf_mod = { fg = c.fg4, bg = "bg_bar" },
    buf_omitter = { fg = c.blue, bg = "bg_bar" },
    buf_omitter_sep = { fg = c.bg4, bg = "bg_bar" },
    buf_pinned = { fg = c.fg4, bg = "bg_bar" },
    buf_order = { fg = c.fg4, bg = "bg_bar" },
    buf_text = { fg = c.fg4, bg = "bg_bar" },
    bufc = { fg = c.fg2, bg = bg_bufc },
    bufc_disambiguation = { link = t and "ms_i_none" or "ms_i_bg0" },
    bufc_indicator = { link = t and "ms_b_none" or "ms_b_bg0" },
    bufc_mod = { fg = c.green, bg = bg_bufc },
    bufc_pinned = { fg = c.fg0, bg = bg_bufc },
    bufc_order = { link = t and "ms_bi_none" or "ms_bi_bg0" },
    bufc_text = { link = t and "ms_bi_none" or "ms_bi_bg0" },
    bufc_error = { fg = c.red, bg = bg_bufc, bold = true, italic = true },
    bufc_warn = { fg = c.yellow, bg = bg_bufc, bold = true, italic = true },
    bufc_hint = { fg = c.purple, bg = bg_bufc, bold = true, italic = true },
    bufc_info = { fg = c.green, bg = bg_bufc, bold = true, italic = true },

    ---! cwd
    cwd_text = { link = "mf_b_bg0" },
    cwd_sep = { link = "ms_b_none" },

    ---! devmode
    devmode_text = { fg = c.bg0, bg = c.orange, bold = true },
    devmode_render_count_text = { fg = c.bg0, bg = c.orange, bold = true },
    devmode_render_count_sep = { fg = c.orange, bg = c.none, bold = true },

    ---! dir
    dir_path_blur_sep = { fg = c.fg3, bg = "bg_bar" },
    dir_path_blur_text = { fg = cs.mix(c.fg3, c.blue, 80), bg = "bg_bar" },
    dir_path_focus_sep = { fg = c.fg1, bg = "bg_bar", bold = true },
    dir_path_focus_text = { fg = c.brightBlue, bg = "bg_bar", bold = true },
    dir_path_prominent_icon = { fg = c.bg0, bg = c.pink, bold = true },
    dir_path_prominent_text = { fg = c.bg0, bg = c.pink, bold = true },

    ---! file
    file_encoding_text = { fg = c.fg2, bg = "bg_bar" },
    file_format_text = { fg = c.fg2, bg = "bg_bar" },
    file_indent_text = { fg = c.fg2, bg = "bg_bar" },
    file_name_text = { fg = c.fg3, bg = "bg_bar" },
    file_name_text_active = { link = "ms_b_none" },
    file_path_text = { fg = c.fg2, bg = "bg_bar" },
    file_readonly = { fg = c.orange, bg = "bg_bar" },
    file_size_text = { fg = c.fg2, bg = "bg_bar" },
    file_status_text = { fg = c.fg2, bg = "bg_bar" },
    file_type_primary_sep = { fg = bg_pos, bg = c.bg0 },
    file_type_primary_text = { fg = c.fg2, bg = bg_pos, bold = true },
    file_type_text = { fg = c.fg2, bg = "bg_bar" },

    ---! git
    git_branch_sep = { fg = bg_pos, bg = "bg_bar" },
    git_branch_text = { fg = c.fg2, bg = bg_pos, bold = true },

    ---! host
    host_username_sep = { link = "mf_b_bg0" },
    host_username_text = { link = "ms_b_none" },

    ---! lint
    lint_icon_active = { fg = c.green, bg = "bg_bar" },
    lint_icon_inactive = { fg = c.bg4, bg = "bg_bar" },
    lint_text = { fg = c.fg2, bg = "bg_bar" },

    ---! lsp
    lsp_client_text = { fg = c.fg2, bg = "bg_bar" },
    lsp_icon_basedpyright = { fg = c.brightYellow, bg = "bg_bar" },
    lsp_icon_bashls = { fg = c.brightGreen, bg = "bg_bar" },
    lsp_icon_cssls = { fg = c.brightBlue, bg = "bg_bar" },
    lsp_icon_docker_compose_language_service = { fg = c.brightAqua, bg = "bg_bar" },
    lsp_icon_dockerls = { fg = c.brightBlue, bg = "bg_bar" },
    lsp_icon_emmet_language_server = { fg = c.brightYellow, bg = "bg_bar" },
    lsp_icon_eslint = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_icon_html = { fg = c.brightOrange, bg = "bg_bar" },
    lsp_icon_jsonls = { fg = c.brightYellow, bg = "bg_bar" },
    lsp_icon_lua_ls = { fg = c.brightBlue, bg = "bg_bar" },
    lsp_icon_ruff = { fg = c.brightGreen, bg = "bg_bar" },
    lsp_icon_rust_analyzer = { fg = c.brightOrange, bg = "bg_bar" },
    lsp_icon_stylua = { fg = c.brightAqua, bg = "bg_bar" },
    lsp_icon_tailwindcss = { fg = c.brightAqua, bg = "bg_bar" },
    lsp_icon_taplo = { fg = c.brightOrange, bg = "bg_bar" },
    lsp_icon_vtsls = { fg = c.brightBlue, bg = "bg_bar" },
    lsp_icon_vue_ls = { fg = c.brightGreen, bg = "bg_bar" },
    lsp_icon_yamlls = { fg = c.brightYellow, bg = "bg_bar" },
    lsp_diagnostics_error = { fg = c.brightRed, bg = "bg_bar" },
    lsp_diagnostics_warn = { fg = c.brightYellow, bg = "bg_bar" },
    lsp_diagnostics_hint = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_diagnostics_info = { fg = c.brightGreen, bg = "bg_bar" },
    lsp_symbol_icon = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_symbol_icon_Array = { fg = c.brightBlue, bg = "bg_bar" },
    lsp_symbol_icon_Boolean = { fg = c.brightOrange, bg = "bg_bar" },
    lsp_symbol_icon_Class = { fg = c.brightAqua, bg = "bg_bar" },
    lsp_symbol_icon_Color = { fg = c.fg0, bg = "bg_bar" },
    lsp_symbol_icon_Constant = { fg = c.brightOrange, bg = "bg_bar" },
    lsp_symbol_icon_Constructor = { fg = c.brightBlue, bg = "bg_bar" },
    lsp_symbol_icon_Enum = { fg = c.brightBlue, bg = "bg_bar" },
    lsp_symbol_icon_EnumMember = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_symbol_icon_Event = { fg = c.brightYellow, bg = "bg_bar" },
    lsp_symbol_icon_Field = { fg = c.brightRed, bg = "bg_bar" },
    lsp_symbol_icon_File = { fg = c.fg0, bg = "bg_bar" },
    lsp_symbol_icon_Folder = { fg = c.fg0, bg = "bg_bar" },
    lsp_symbol_icon_Function = { fg = c.brightBlue, bg = "bg_bar" },
    lsp_symbol_icon_Identifier = { fg = c.brightRed, bg = "bg_bar" },
    lsp_symbol_icon_Interface = { fg = c.brightGreen, bg = "bg_bar" },
    lsp_symbol_icon_Key = { fg = c.brightRed, bg = "bg_bar" },
    lsp_symbol_icon_Keyword = { fg = c.fg0, bg = "bg_bar" },
    lsp_symbol_icon_Method = { fg = c.brightBlue, bg = "bg_bar" },
    lsp_symbol_icon_Module = { fg = c.brightYellow, bg = "bg_bar" },
    lsp_symbol_icon_Namespace = { fg = c.brightAqua, bg = "bg_bar" },
    lsp_symbol_icon_Null = { fg = c.brightAqua, bg = "bg_bar" },
    lsp_symbol_icon_Number = { fg = c.brightOrange, bg = "bg_bar" },
    lsp_symbol_icon_Object = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_symbol_icon_Operator = { fg = c.fg0, bg = "bg_bar" },
    lsp_symbol_icon_Package = { fg = c.brightGreen, bg = "bg_bar" },
    lsp_symbol_icon_Property = { fg = c.brightRed, bg = "bg_bar" },
    lsp_symbol_icon_Reference = { fg = c.fg0, bg = "bg_bar" },
    lsp_symbol_icon_Snippet = { fg = c.brightRed, bg = "bg_bar" },
    lsp_symbol_icon_String = { fg = c.brightGreen, bg = "bg_bar" },
    lsp_symbol_icon_Struct = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_symbol_icon_Structure = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_symbol_icon_Text = { fg = c.brightGreen, bg = "bg_bar" },
    lsp_symbol_icon_Type = { fg = c.brightYellow, bg = "bg_bar" },
    lsp_symbol_icon_TypeParameter = { fg = c.brightRed, bg = "bg_bar" },
    lsp_symbol_icon_Unit = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_symbol_icon_Value = { fg = c.brightAqua, bg = "bg_bar" },
    lsp_symbol_icon_Variable = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_symbol_sep = { fg = c.fg2, bg = "bg_bar" },
    lsp_symbol_text = { fg = c.fg2, bg = "bg_bar" },

    ---! nvim
    nvim_mode_sep = { link = "ms_b_bg2" },
    nvim_mode_text = { link = "mf_b_bg0" },
    nvim_msg_changes = { fg = c.fg3, bg = "bg_bar" },
    nvim_msg_command = { fg = c.pink, bg = "bg_bar" },
    nvim_msg_lsp = { fg = c.fg4, bg = "bg_bar" },
    nvim_msg_mode = { fg = c.yellow, bg = "bg_bar" },
    nvim_nr = { fg = c.fg3, bg = "bg_bar" },
    nvim_pid = { fg = c.fg3, bg = "bg_bar" },
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
    nvim_tab_item = { fg = c.fg1, bg = "bg_bar" },
    nvim_tab_item_cur = { fg = c.red, bg = bg_bufc },
    nvim_tab_toggle = { fg = c.bg1, bg = c.green },

    ---! explorer
    explorer_detached = { fg = c.red, bg = "bg_bar" },
    explorer_flag_aqua = { fg = c.bg0, bg = c.brightAqua },
    explorer_flag_blue = { fg = c.bg0, bg = c.brightBlue },
    explorer_flag_green = { fg = c.bg0, bg = c.brightGreen },
    explorer_flag_grey = { fg = c.fg3, bg = c.bg2 },
    explorer_flag_orange = { fg = c.bg0, bg = c.brightOrange },
    explorer_flag_purple = { fg = c.bg0, bg = c.brightPurple },
    explorer_flag_red = { fg = c.bg0, bg = c.brightRed },
    explorer_flag_yellow = { fg = c.bg0, bg = c.brightYellow },
    explorer_path = { fg = c.pink, bg = "bg_bar", bold = true },
    explorer_path_detached = { fg = c.red, bg = "bg_bar", bold = true },

    ---! picker
    picker = { sp = c.pink, underline = true },
    picker_flag_grey = { fg = c.fg3, bg = c.bg2, sp = c.pink, underline = true },
    picker_flag_red = { fg = c.bg0, bg = c.brightRed, sp = c.pink, underline = true },
    picker_flag_green = { fg = c.bg0, bg = c.brightGreen, sp = c.pink, underline = true },
    picker_flag_yellow = { fg = c.bg0, bg = c.brightYellow, sp = c.pink, underline = true },
    picker_flag_blue = { fg = c.bg0, bg = c.brightBlue, sp = c.pink, underline = true },
    picker_flag_purple = { fg = c.bg0, bg = c.brightPurple, sp = c.pink, underline = true },
    picker_flag_aqua = { fg = c.bg0, bg = c.brightAqua, sp = c.pink, underline = true },
    picker_flag_orange = { fg = c.bg0, bg = c.brightOrange, sp = c.pink, underline = true },
    picker_result_pos_text = { fg = c.fg4, bg = "bg_bar", sp = c.pink, underline = true },

    ---! python
    python_env_text = { fg = c.fg2, bg = "bg_bar" },

    ---! searcher
    searcher = { fg = c.pink, sp = c.pink, underline = true },

    ---! sidebar
    sidebar_blank = { fg = c.fg1, bg = "bg_bar" },
    sidebar_split = { fg = c.bg4, bg = "bg_bar" },

    ---! notepad
    notepad_button = { fg = c.fg3, bg = "bg_bar" },
    notepad_source = { fg = c.bg1, bg = c.pink, bold = true },
    notepad_source_sep = { fg = c.pink, bg = "bg_bar" },
    notepad_name = { fg = c.fg3, bg = c.bg3 },
    notepad_index = { fg = c.fg3, bg = c.bg4 },
    notepad_sep_left = { fg = c.bg3, bg = "bg_bar" },
    notepad_sep_middle = { fg = c.bg4, bg = "bg_bar" },
    notepad_sep_right = { fg = c.bg3, bg = "bg_bar" },
    notepadc_name = { link = "mf_b_bg0" },
    notepadc_index = { link = "mf_b_bg0" },
    notepadc_sep_left = { link = "ms_b_none" },
    notepadc_sep_middle = { link = "mf_b_bg0" },
    notepadc_sep_right = { link = "ms_b_none" },

    ---! term
    term_button = { fg = c.fg3, bg = c.bg4 },
    term_index = { fg = c.fg3, bg = c.bg4 },
    term_name = { fg = c.fg3, bg = c.bg3 },
    term_sep_left = { fg = c.bg3, bg = "bg_bar" },
    term_sep_right = { fg = c.bg4, bg = "bg_bar" },
    termc_index = { link = "mf_b_bg0" },
    termc_name = { link = "mf_b_bg0" },
    termc_sep_left = { link = "ms_b_none" },
    termc_sep_middle = { link = "mf_b_bg0" },
    termc_sep_right = { link = "ms_b_none" },
  }

  local positions = { "f_sl", "f_tl", "f_wl" } ---@type ark.e.NvimbarPositionEnum[]

  ---@class ark.theme.hlgroup.nvimbar : table<string, ark.t.theme.IHlgroup>
  ---@field public f_sl_bg              { bg: string, sp?: string }
  ---@field public f_tl_bg              { bg: string, sp?: string }
  ---@field public f_wl_bg              { bg: string, sp?: string }
  ---@field public f_sl_buf             { bg: string, sp?: string }
  ---@field public f_tl_buf             { bg: string, sp?: string }
  ---@field public f_wl_buf             { bg: string, sp?: string }
  ---@field public f_sl_bufc            { bg: string, sp?: string }
  ---@field public f_tl_bufc            { bg: string, sp?: string }
  ---@field public f_wl_bufc            { bg: string, sp?: string }
  local results = {}
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
  return results
end

return M
