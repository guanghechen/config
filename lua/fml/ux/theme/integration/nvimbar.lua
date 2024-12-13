---@param context                       fml.t.ux.IThemeContext
---@return fml.ux.theme.integration.nvimbar.hlgroups
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type eve.lib.collection.theme.IPalette
  local t = context.transparency ---@type boolean
  local bg_buf_cur = t and "none" or c.bg0 ---@type string
  local bg_mode = t and "none" or c.bg2 ---@type string

  local bgs = {
    f_sl = t and "none" or c.bg1,
    f_tl = t and "none" or c.bg1,
    f_wl = "none",
  }

  ---@type table<string, eve.lib.collection.theme.IHlgroup>
  local hlgroup_map = {
    bg = { fg = "bg_bar", bg = "bg_bar" },
    buf = { fg = c.bg4, bg = "bg_bar" },
    buf_indicator = { fg = c.purple, bg = bg_buf_cur, bold = true },
    buf_mod = { fg = c.red, bg = "bg_bar" },
    buf_ommitter = { fg = c.blue, bg = "bg_bar" },
    buf_ommitter_sep = { fg = c.bg4, bg = "bg_bar" },
    buf_sep = { fg = c.fg4, bg = "bg_bar" },
    buf_text = { fg = c.fg4, bg = "bg_bar" },
    buf_cur = { fg = c.fg2, bg = bg_buf_cur },
    buf_cur_mod = { fg = c.green, bg = bg_buf_cur },
    buf_cur_text = { fg = c.fg2, bg = bg_buf_cur, bold = true, italic = true },
    buf_cur_error = { fg = c.red, bg = bg_buf_cur, bold = true, italic = true },
    buf_cur_warn = { fg = c.yellow, bg = bg_buf_cur, bold = true, italic = true },
    buf_cur_hint = { fg = c.purple, bg = bg_buf_cur, bold = true, italic = true },
    buf_cur_info = { fg = c.green, bg = bg_buf_cur, bold = true, italic = true },
    copilot_InProgress = { fg = c.aqua, bg = "bg_bar" },
    copilot_Inactive = { fg = c.red, bg = "bg_bar" },
    copilot_Normal = { fg = c.blue, bg = "bg_bar" },
    copilot_Warning = { fg = c.yellow, bg = "bg_bar" },
    cwd = { fg = c.bg0, bg = c.green, bold = true },
    debug_render_count = { fg = c.bg0, bg = c.orange, bold = true },
    devmode = { fg = c.bg0, bg = c.yellow, bold = true },
    diagnostics_error = { fg = c.red, bg = "bg_bar" },
    diagnostics_warn = { fg = c.yellow, bg = "bg_bar" },
    diagnostics_hint = { fg = c.purple, bg = "bg_bar" },
    diagnostics_info = { fg = c.green, bg = "bg_bar" },
    dirpath_sep = { fg = c.fg1, bg = "bg_bar" },
    dirpath_text = { fg = c.blue, bg = "bg_bar" },
    filename = { fg = c.fg1, bg = "bg_bar" },
    filename_text = { fg = c.fg3, bg = "bg_bar" },
    filename_text_cur = { fg = c.fg2, bg = "bg_bar", bold = true, italic = true },
    flag = { fg = c.fg1, bg = t and c.bg2 or c.bg3 },
    flag_enabled = { fg = c.bg1, bg = c.blue },
    flag_scope = { fg = c.bg1, bg = c.orange },
    indicator = { fg = c.orange, bg = "bg_bar" },
    lsp_icon = { fg = c.neutral_purple, bg = "bg_bar" },
    lsp_icon_Array = { fg = c.blue, bg = "bg_bar" },
    lsp_icon_Boolean = { fg = c.orange, bg = "bg_bar" },
    lsp_icon_Class = { fg = c.neutral_aqua, bg = "bg_bar" },
    lsp_icon_Color = { fg = c.fg1, bg = "bg_bar" },
    lsp_icon_Constant = { fg = c.orange, bg = "bg_bar" },
    lsp_icon_Constructor = { fg = c.blue, bg = "bg_bar" },
    lsp_icon_Enum = { fg = c.blue, bg = "bg_bar" },
    lsp_icon_EnumMember = { fg = c.neutral_purple, bg = "bg_bar" },
    lsp_icon_Event = { fg = c.yellow, bg = "bg_bar" },
    lsp_icon_Field = { fg = c.red, bg = "bg_bar" },
    lsp_icon_File = { fg = c.fg1, bg = "bg_bar" },
    lsp_icon_Folder = { fg = c.fg1, bg = "bg_bar" },
    lsp_icon_Function = { fg = c.blue, bg = "bg_bar" },
    lsp_icon_Identifier = { fg = c.red, bg = "bg_bar" },
    lsp_icon_Interface = { fg = c.green, bg = "bg_bar" },
    lsp_icon_Key = { fg = c.red, bg = "bg_bar" },
    lsp_icon_Keyword = { fg = c.fg1, bg = "bg_bar" },
    lsp_icon_Method = { fg = c.blue, bg = "bg_bar" },
    lsp_icon_Module = { fg = c.yellow, bg = "bg_bar" },
    lsp_icon_Namespace = { fg = c.neutral_aqua, bg = "bg_bar" },
    lsp_icon_Null = { fg = c.aqua, bg = "bg_bar" },
    lsp_icon_Number = { fg = c.orange, bg = "bg_bar" },
    lsp_icon_Object = { fg = c.neutral_purple, bg = "bg_bar" },
    lsp_icon_Operator = { fg = c.fg1, bg = "bg_bar" },
    lsp_icon_Package = { fg = c.green, bg = "bg_bar" },
    lsp_icon_Property = { fg = c.red, bg = "bg_bar" },
    lsp_icon_Reference = { fg = c.fg1, bg = "bg_bar" },
    lsp_icon_Snippet = { fg = c.red, bg = "bg_bar" },
    lsp_icon_String = { fg = c.green, bg = "bg_bar" },
    lsp_icon_Struct = { fg = c.neutral_purple, bg = "bg_bar" },
    lsp_icon_Structure = { fg = c.neutral_purple, bg = "bg_bar" },
    lsp_icon_Text = { fg = c.green, bg = "bg_bar" },
    lsp_icon_Type = { fg = c.yellow, bg = "bg_bar" },
    lsp_icon_TypeParameter = { fg = c.red, bg = "bg_bar" },
    lsp_icon_Unit = { fg = c.neutral_purple, bg = "bg_bar" },
    lsp_icon_Value = { fg = c.aqua, bg = "bg_bar" },
    lsp_icon_Variable = { fg = c.neutral_purple, bg = "bg_bar" },
    lsp_sep = { fg = c.fg3, bg = "bg_bar" },
    lsp_text = { fg = c.fg3, bg = "bg_bar" },
    noice_command = { fg = c.fg1, bg = "bg_bar" },
    noice_mode = { fg = c.yellow, bg = "bg_bar" },
    pos = { fg = c.bg1, bg = c.fg3 },
    pos_bot = { fg = c.bg1, bg = c.green, bold = true },
    pos_top = { fg = c.bg1, bg = c.green, bold = true },
    readonly = { fg = c.orange, bg = "bg_bar" },
    sidebar_blank = { fg = c.fg1, bg = "bg_bar" },
    sidebar_indicator = { fg = c.orange, bg = "bg_bar" },
    sidebar_split = { fg = c.bg4, bg = "bg_bar" },
    sidebar_text = { fg = c.fg2, bg = "bg_bar", bold = true },
    tab_add = { fg = c.fg1, bg = c.bg3 },
    tab_item = { fg = c.fg1, bg = "bg_bar" },
    tab_item_cur = { fg = c.red, bg = bg_buf_cur },
    tab_toggle = { fg = c.bg1, bg = c.green },
    text = { fg = c.fg2, bg = "bg_bar" },
    text_command = { fg = c.green, bg = bg_mode, bold = true },
    text_confirm = { fg = c.neutral_aqua, bg = bg_mode, bold = true },
    text_insert = { fg = c.neutral_purple, bg = bg_mode, bold = true },
    text_normal = { fg = c.aqua, bg = bg_mode, bold = true },
    text_nterminal = { fg = c.yellow, bg = bg_mode, bold = true },
    text_replace = { fg = c.yellow, bg = bg_mode, bold = true },
    text_select = { fg = c.blue, bg = bg_mode, bold = true },
    text_terminal = { fg = c.green, bg = bg_mode, bold = true },
    text_visual = { fg = c.aqua, bg = bg_mode },
    username = { fg = c.bg1, bg = c.blue },
  }

  local positions = { "f_sl", "f_tl", "f_wl" } ---@type eve.lib.ux.nvimbar.Position[]

  ---@class fml.ux.theme.integration.nvimbar.hlgroups : table<string, eve.lib.collection.theme.IHlgroup>
  ---@field public f_sl_bg              { bg: string }
  ---@field public f_tl_bg              { bg: string }
  ---@field public f_wl_bg              { bg: string }
  ---@field public f_sl_buf             { bg: string }
  ---@field public f_tl_buf             { bg: string }
  ---@field public f_wl_buf             { bg: string }
  ---@field public f_sl_buf_cur         { bg: string }
  ---@field public f_tl_buf_cur         { bg: string }
  ---@field public f_wl_buf_cur         { bg: string }
  ---@field public f_sl_filename        { bg: string }
  ---@field public f_tl_filename        { bg: string }
  ---@field public f_wl_filename        { bg: string }
  local results = {}
  for _, position in ipairs(positions) do
    for hlname, hlgroup in pairs(hlgroup_map) do
      results[position .. "_" .. hlname] = {
        fg = hlgroup.fg == "bg_bar" and bgs[position] or hlgroup.fg,
        bg = hlgroup.bg == "bg_bar" and bgs[position] or hlgroup.bg,
        bold = hlgroup.bold,
        italic = hlgroup.italic,
        underline = hlgroup.underline,
      }
    end
  end
  return results
end

return gen_hlgroup_map
