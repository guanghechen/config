---@class eve.constant.hlgroup.nvimbar
local M = {}

---@param context                       eve.t.theme.IContext
---@return eve.constant.hlgroup.nvimbar
function M.gen_hlgroup_map(context)
  local cs = eve.std.color
  local c = context.scheme.palette ---@type eve.t.theme.IPalette
  local t = context.transparency ---@type boolean
  local bg_bufc = t and c.none or c.bg0 ---@type string
  local bg_pos = t and c.bg0 or c.bg2 ---@type string

  local bgs = {
    f_sl = c.none,
    f_tl = c.none,
    f_wl = c.none,
  }

  ---@type table<string, eve.t.theme.IHlgroup>
  local hlgroup_map = {
    bg = { fg = "bg_bar", bg = "bg_bar" },
    text = { fg = c.fg2, bg = "bg_bar" },

    ------------------------------------------------------------------------------------------------

    ai_text = { fg = c.fg2, bg = "bg_bar" },
    ai_status_InProgress = { fg = c.aqua, bg = "bg_bar" },
    ai_status_Inactive = { fg = c.red, bg = "bg_bar" },
    ai_status_Normal = { fg = c.fg1, bg = "bg_bar" },
    ai_status_Warning = { fg = c.yellow, bg = "bg_bar" },
    buf = { fg = c.bg4, bg = "bg_bar" },
    buf_indicator = { fg = c.fg4, bg = "bg_bar", bold = true },
    buf_mod = { fg = c.fg4, bg = "bg_bar" },
    buf_omitter = { fg = c.blue, bg = "bg_bar" },
    buf_omitter_sep = { fg = c.bg4, bg = "bg_bar" },
    buf_pinned = { fg = c.fg4, bg = "bg_bar" },
    buf_order = { fg = c.fg4, bg = "bg_bar" },
    buf_text = { fg = c.fg4, bg = "bg_bar" },
    bufc = { fg = c.fg2, bg = bg_bufc },
    bufc_indicator = { link = t and "ms_b_none" or "ms_b_bg0" },
    bufc_mod = { fg = c.green, bg = bg_bufc },
    bufc_pinned = { fg = c.fg0, bg = bg_bufc },
    bufc_order = { link = t and "ms_bi_none" or "ms_bi_bg0" },
    bufc_text = { link = t and "ms_bi_none" or "ms_bi_bg0" },
    bufc_error = { fg = c.red, bg = bg_bufc, bold = true, italic = true },
    bufc_warn = { fg = c.yellow, bg = bg_bufc, bold = true, italic = true },
    bufc_hint = { fg = c.purple, bg = bg_bufc, bold = true, italic = true },
    bufc_info = { fg = c.green, bg = bg_bufc, bold = true, italic = true },
    copilot_InProgress = { fg = c.aqua, bg = "bg_bar" },
    copilot_Inactive = { fg = c.red, bg = "bg_bar" },
    copilot_Normal = { fg = c.fg1, bg = "bg_bar" },
    copilot_Warning = { fg = c.yellow, bg = "bg_bar" },
    cwd_text = { link = "mf_b_bg0" },
    cwd_sep = { link = "ms_b_none" },
    debug_render_count_text = { fg = c.bg0, bg = c.orange, bold = true },
    debug_render_count_sep = { fg = c.orange, bg = c.bg1, bold = true },
    devmode = { fg = c.bg0, bg = c.yellow, bold = true },
    diagnostics_error = { fg = c.red, bg = "bg_bar" },
    diagnostics_warn = { fg = c.yellow, bg = "bg_bar" },
    diagnostics_hint = { fg = c.purple, bg = "bg_bar" },
    diagnostics_info = { fg = c.green, bg = "bg_bar" },
    dirpath_blur_sep = { fg = c.fg3, bg = "bg_bar" },
    dirpath_blur_text = { fg = cs.mix(c.fg3, c.blue, 80), bg = "bg_bar" },
    dirpath_focus_sep = { fg = c.fg1, bg = "bg_bar", bold = true },
    dirpath_focus_text = { fg = c.blue, bg = "bg_bar", bold = true },
    dirpath_prominent_icon = { fg = c.bg0, bg = c.pink, bold = true },
    dirpath_prominent_text = { fg = c.bg0, bg = c.pink, bold = true },
    filename = { fg = c.fg1, bg = "bg_bar" },
    filename_blur_text = { fg = c.fg3, bg = "bg_bar" },
    flag = { fg = c.fg1, bg = t and c.bg2 or c.bg3 },
    flag_sep = { fg = c.bg4, bg = t and c.bg2 or c.bg3 },
    flag_enabled = { fg = c.bg1, bg = c.blue },
    flag_enabled_sep = { fg = c.bg4, bg = c.blue },
    flag_scope = { fg = c.bg1, bg = c.blue },
    flag_scope_sep = { fg = c.bg4, bg = c.blue },
    flag_popup = { fg = c.bg1, bg = c.purple },
    flag_popup_sep = { fg = c.bg1, bg = c.purple },
    git_text = { fg = c.fg1, bg = "bg_bar" },
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
    mode_text = { link = "mf_b_bg0" },
    mode_sep = { link = t and "ms_b_none" or "ms_b_bg2" },
    msg_changes = { fg = c.fg3, bg = "bg_bar" },
    msg_command = { fg = c.pink, bg = "bg_bar" },
    msg_lsp = { fg = c.fg4, bg = "bg_bar" },
    msg_mode = { fg = c.yellow, bg = "bg_bar" },
    neotree_blank = { fg = c.fg1, bg = "bg_bar" },
    neotree_sep = { fg = bg_pos, bg = bg_pos, bold = true },
    neotree_split = { fg = c.bg4, bg = "bg_bar" },
    neotree_text = { fg = c.fg4, bg = bg_pos, bold = true },
    pos_sep = { fg = bg_pos, bg = "bg_bar" },
    pos_text_anchor = { fg = c.fg2, bg = "bg_bar" },
    pos_text_percentage = { fg = c.fg2, bg = bg_pos, bold = true },
    python_env = { fg = c.fg3, bg = "bg_bar" },
    readonly = { fg = c.orange, bg = "bg_bar" },
    sidebar_blank = { fg = c.fg1, bg = "bg_bar" },
    sidebar_split = { fg = c.bg4, bg = "bg_bar" },
    tab_add = { fg = c.fg1, bg = c.bg3 },
    tab_item = { fg = c.fg1, bg = "bg_bar" },
    tab_item_cur = { fg = c.red, bg = bg_bufc },
    tab_toggle = { fg = c.bg1, bg = c.green },
    username_text = { link = t and "ms_b_bg0" or "ms_b_none" },
    username_sep = { link = t and "mf_b_bg0" or "mf_b_none" },
  }

  local positions = { "f_sl", "f_tl", "f_wl" } ---@type eve.ux.nvimbar.Position[]

  ---@class eve.constant.hlgroup.nvimbar : table<string, eve.t.theme.IHlgroup>
  ---@field public f_sl_bg              { bg: string, sp?: string }
  ---@field public f_tl_bg              { bg: string, sp?: string }
  ---@field public f_wl_bg              { bg: string, sp?: string }
  ---@field public f_sl_buf             { bg: string, sp?: string }
  ---@field public f_tl_buf             { bg: string, sp?: string }
  ---@field public f_wl_buf             { bg: string, sp?: string }
  ---@field public f_sl_bufc            { bg: string, sp?: string }
  ---@field public f_tl_bufc            { bg: string, sp?: string }
  ---@field public f_wl_bufc            { bg: string, sp?: string }
  ---@field public f_sl_filename        { bg: string, sp?: string }
  ---@field public f_tl_filename        { bg: string, sp?: string }
  ---@field public f_wl_filename        { bg: string, sp?: string }
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
