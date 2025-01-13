local cs = require("eve.builtin.color")

---@param context                       eve.t.theme.IContext
---@return eve.constant.hlgroup.nvimbar
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type eve.t.theme.IPalette
  local t = context.transparency ---@type boolean
  local bg_bufc = t and "none" or c.bg0 ---@type string
  local bg_git = t and c.bg0 or c.bg2 ---@type string
  local bg_username = cs.mix(c.bg0, c.pink, 90) ---@type string

  local mc = {
    command = c.green,
    confirm = c.brightAqua,
    insert = c.purple,
    normal = c.aqua,
    nterminal = c.yellow,
    replace = c.brightYellow,
    select = c.orange,
    terminal = c.green,
    visual = c.orange,
  }

  local bgs = {
    f_sl = t and "none" or c.bg1,
    f_tl = t and "none" or c.bg1,
    f_wl = "none",
  }

  ---@type table<string, eve.t.theme.IHlgroup>
  local hlgroup_map = {
    bg = { fg = "bg_bar", bg = "bg_bar" },
    ai_text = { fg = c.fg2, bg = "bg_bar" },
    ai_status_InProgress = { fg = c.aqua, bg = "bg_bar" },
    ai_status_Inactive = { fg = c.red, bg = "bg_bar" },
    ai_status_Normal = { fg = c.fg1, bg = "bg_bar" },
    ai_status_Warning = { fg = c.yellow, bg = "bg_bar" },
    buf = { fg = c.bg4, bg = "bg_bar" },
    buf_indicator = { fg = c.purple, bg = bg_bufc, bold = true },
    buf_mod = { fg = c.fg4, bg = "bg_bar" },
    buf_omitter = { fg = c.blue, bg = "bg_bar" },
    buf_omitter_sep = { fg = c.bg4, bg = "bg_bar" },
    buf_pinned = { fg = c.fg4, bg = "bg_bar" },
    buf_order = { fg = c.fg4, bg = "bg_bar" },
    buf_sep = { fg = c.fg4, bg = "bg_bar" },
    buf_text = { fg = c.fg4, bg = "bg_bar" },
    bufc = { fg = c.fg2, bg = bg_bufc },
    bufc_mod = { fg = c.green, bg = bg_bufc },
    bufc_pinned = { fg = c.fg0, bg = bg_bufc },
    bufc_order = { fg = c.fg0, bg = bg_bufc },
    bufc_text = { fg = c.fg2, bg = bg_bufc, bold = true, italic = true },
    bufc_error = { fg = c.red, bg = bg_bufc, bold = true, italic = true },
    bufc_warn = { fg = c.yellow, bg = bg_bufc, bold = true, italic = true },
    bufc_hint = { fg = c.purple, bg = bg_bufc, bold = true, italic = true },
    bufc_info = { fg = c.green, bg = bg_bufc, bold = true, italic = true },
    copilot_InProgress = { fg = c.aqua, bg = "bg_bar" },
    copilot_Inactive = { fg = c.red, bg = "bg_bar" },
    copilot_Normal = { fg = c.fg1, bg = "bg_bar" },
    copilot_Warning = { fg = c.yellow, bg = "bg_bar" },
    cwd_sep_command = { fg = mc.command, bg = "bg_bar", bold = true },
    cwd_sep_confirm = { fg = mc.confirm, bg = "bg_bar", bold = true },
    cwd_sep_insert = { fg = mc.insert, bg = "bg_bar", bold = true },
    cwd_sep_normal = { fg = mc.normal, bg = "bg_bar", bold = true },
    cwd_sep_nterminal = { fg = mc.nterminal, bg = "bg_bar", bold = true },
    cwd_sep_replace = { fg = mc.replace, bg = "bg_bar", bold = true },
    cwd_sep_select = { fg = mc.select, bg = "bg_bar", bold = true },
    cwd_sep_terminal = { fg = mc.terminal, bg = "bg_bar", bold = true },
    cwd_sep_visual = { fg = mc.visual, bg = "bg_bar", bold = true },
    cwd_text_command = { fg = c.bg1, bg = mc.command, bold = true },
    cwd_text_confirm = { fg = c.bg1, bg = mc.confirm, bold = true },
    cwd_text_insert = { fg = c.bg1, bg = mc.insert, bold = true },
    cwd_text_normal = { fg = c.bg1, bg = mc.normal, bold = true },
    cwd_text_nterminal = { fg = c.bg1, bg = mc.nterminal, bold = true },
    cwd_text_replace = { fg = c.bg1, bg = mc.replace, bold = true },
    cwd_text_select = { fg = c.bg1, bg = mc.select, bold = true },
    cwd_text_terminal = { fg = c.bg1, bg = mc.terminal, bold = true },
    cwd_text_visual = { fg = c.bg1, bg = mc.visual, bold = true },
    debug_render_count = { fg = c.bg0, bg = c.orange, bold = true },
    devmode = { fg = c.bg0, bg = c.yellow, bold = true },
    diagnostics_error = { fg = c.red, bg = "bg_bar" },
    diagnostics_warn = { fg = c.yellow, bg = "bg_bar" },
    diagnostics_hint = { fg = c.purple, bg = "bg_bar" },
    diagnostics_info = { fg = c.green, bg = "bg_bar" },
    dirpath_icon = { fg = c.blue, bg = "bg_bar" },
    dirpath_sep = { fg = c.fg1, bg = "bg_bar" },
    dirpath_text = { fg = c.blue, bg = "bg_bar" },
    dirpath_prominent_icon = { fg = c.bg0, bg = c.pink, bold = true },
    dirpath_prominent_text = { fg = c.bg0, bg = c.pink, bold = true },
    filename = { fg = c.fg1, bg = "bg_bar" },
    filename_text = { fg = c.fg3, bg = "bg_bar" },
    filename_text_cur = { fg = c.fg2, bg = "bg_bar", bold = true, italic = true },
    flag = { fg = c.fg1, bg = t and c.bg2 or c.bg3 },
    flag_enabled = { fg = c.bg1, bg = c.blue },
    flag_scope = { fg = c.bg1, bg = c.orange },
    focused_indicator = { fg = c.bg0, bg = c.pink },
    git_text = { fg = c.fg1, bg = bg_git },
    git_sep = { fg = bg_git, bg = "bg_bar" },
    indicator = { fg = c.orange, bg = "bg_bar" },
    lsp_icon = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_icon_Array = { fg = c.blue, bg = "bg_bar" },
    lsp_icon_Boolean = { fg = c.orange, bg = "bg_bar" },
    lsp_icon_Class = { fg = c.brightAqua, bg = "bg_bar" },
    lsp_icon_Color = { fg = c.fg1, bg = "bg_bar" },
    lsp_icon_Constant = { fg = c.orange, bg = "bg_bar" },
    lsp_icon_Constructor = { fg = c.blue, bg = "bg_bar" },
    lsp_icon_Enum = { fg = c.blue, bg = "bg_bar" },
    lsp_icon_EnumMember = { fg = c.brightPurple, bg = "bg_bar" },
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
    lsp_icon_Namespace = { fg = c.brightAqua, bg = "bg_bar" },
    lsp_icon_Null = { fg = c.aqua, bg = "bg_bar" },
    lsp_icon_Number = { fg = c.orange, bg = "bg_bar" },
    lsp_icon_Object = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_icon_Operator = { fg = c.fg1, bg = "bg_bar" },
    lsp_icon_Package = { fg = c.green, bg = "bg_bar" },
    lsp_icon_Property = { fg = c.red, bg = "bg_bar" },
    lsp_icon_Reference = { fg = c.fg1, bg = "bg_bar" },
    lsp_icon_Snippet = { fg = c.red, bg = "bg_bar" },
    lsp_icon_String = { fg = c.green, bg = "bg_bar" },
    lsp_icon_Struct = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_icon_Structure = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_icon_Text = { fg = c.green, bg = "bg_bar" },
    lsp_icon_Type = { fg = c.yellow, bg = "bg_bar" },
    lsp_icon_TypeParameter = { fg = c.red, bg = "bg_bar" },
    lsp_icon_Unit = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_icon_Value = { fg = c.aqua, bg = "bg_bar" },
    lsp_icon_Variable = { fg = c.brightPurple, bg = "bg_bar" },
    lsp_sep = { fg = c.fg3, bg = "bg_bar" },
    lsp_text = { fg = c.fg3, bg = "bg_bar" },
    mode_sep_command = { fg = mc.command, bg = "bg_bar", bold = true },
    mode_sep_confirm = { fg = mc.confirm, bg = "bg_bar", bold = true },
    mode_sep_insert = { fg = mc.insert, bg = "bg_bar", bold = true },
    mode_sep_normal = { fg = mc.normal, bg = "bg_bar", bold = true },
    mode_sep_nterminal = { fg = mc.nterminal, bg = "bg_bar", bold = true },
    mode_sep_replace = { fg = mc.replace, bg = "bg_bar", bold = true },
    mode_sep_select = { fg = mc.select, bg = "bg_bar", bold = true },
    mode_sep_terminal = { fg = mc.terminal, bg = "bg_bar", bold = true },
    mode_sep_visual = { fg = mc.visual, bg = "bg_bar", bold = true },
    mode_sep_git_command = { fg = mc.command, bg = bg_git, bold = true },
    mode_sep_git_confirm = { fg = mc.confirm, bg = bg_git, bold = true },
    mode_sep_git_insert = { fg = mc.insert, bg = bg_git, bold = true },
    mode_sep_git_normal = { fg = mc.normal, bg = bg_git, bold = true },
    mode_sep_git_nterminal = { fg = mc.nterminal, bg = bg_git, bold = true },
    mode_sep_git_replace = { fg = mc.replace, bg = bg_git, bold = true },
    mode_sep_git_select = { fg = mc.select, bg = bg_git, bold = true },
    mode_sep_git_terminal = { fg = mc.terminal, bg = bg_git, bold = true },
    mode_sep_git_visual = { fg = mc.visual, bg = bg_git, bold = true },
    mode_text_command = { fg = c.bg1, bg = mc.command, bold = true },
    mode_text_confirm = { fg = c.bg1, bg = mc.confirm, bold = true },
    mode_text_insert = { fg = c.bg1, bg = mc.insert, bold = true },
    mode_text_normal = { fg = c.bg1, bg = mc.normal, bold = true },
    mode_text_nterminal = { fg = c.bg1, bg = mc.nterminal, bold = true },
    mode_text_replace = { fg = c.bg1, bg = mc.replace, bold = true },
    mode_text_select = { fg = c.bg1, bg = mc.select, bold = true },
    mode_text_terminal = { fg = c.bg1, bg = mc.terminal, bold = true },
    mode_text_visual = { fg = c.bg1, bg = mc.visual, bold = true },
    noice_command = { fg = c.fg2, bg = "bg_bar" },
    noice_mode = { fg = c.yellow, bg = "bg_bar" },
    pos = { fg = c.fg2, bg = "bg_bar" },
    pos_bot = { fg = c.fg2, bg = "bg_bar", bold = true },
    pos_top = { fg = c.fg2, bg = "bg_bar", bold = true },
    readonly = { fg = c.orange, bg = "bg_bar" },
    sidebar_blank = { fg = c.fg1, bg = "bg_bar" },
    sidebar_indicator = { fg = c.orange, bg = "bg_bar" },
    sidebar_split = { fg = c.bg4, bg = "bg_bar" },
    sidebar_text = { fg = c.fg2, bg = "bg_bar", bold = true },
    tab_add = { fg = c.fg1, bg = c.bg3 },
    tab_item = { fg = c.fg1, bg = "bg_bar" },
    tab_item_cur = { fg = c.red, bg = bg_bufc },
    tab_toggle = { fg = c.bg1, bg = c.green },
    text = { fg = c.fg2, bg = "bg_bar" },
    username_text = { fg = c.bg1, bg = bg_username, bold = true },
    username_sep_command = { fg = bg_username, bg = mc.command, bold = true },
    username_sep_confirm = { fg = bg_username, bg = mc.confirm, bold = true },
    username_sep_insert = { fg = bg_username, bg = mc.insert, bold = true },
    username_sep_normal = { fg = bg_username, bg = mc.normal, bold = true },
    username_sep_nterminal = { fg = bg_username, bg = mc.nterminal, bold = true },
    username_sep_replace = { fg = bg_username, bg = mc.replace, bold = true },
    username_sep_select = { fg = bg_username, bg = mc.select, bold = true },
    username_sep_terminal = { fg = bg_username, bg = mc.terminal, bold = true },
    username_sep_visual = { fg = bg_username, bg = mc.visual, bold = true },
  }

  local positions = { "f_sl", "f_tl", "f_wl" } ---@type fml.ux.nvimbar.Position[]

  ---@class eve.constant.hlgroup.nvimbar : table<string, eve.theme.IHlgroup>
  ---@field public f_sl_bg              { bg: string }
  ---@field public f_tl_bg              { bg: string }
  ---@field public f_wl_bg              { bg: string }
  ---@field public f_sl_buf             { bg: string }
  ---@field public f_tl_buf             { bg: string }
  ---@field public f_wl_buf             { bg: string }
  ---@field public f_sl_bufc         { bg: string }
  ---@field public f_tl_bufc         { bg: string }
  ---@field public f_wl_bufc         { bg: string }
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
