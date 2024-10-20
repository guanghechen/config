---@param context                       t.ghc.ux.IThemeContext
---@return ghc.ux.theme.integration.winline.hlgroups
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette
  local t = context.transparency ---@type boolean
  local bg_winline = c.bg2

  ---@class ghc.ux.theme.integration.winline.hlgroups : table<string, t.fml.ux.theme.IHlgroup>
  local hlgroup_map = {
    f_wl_bg = { fg = t and "none" or bg_winline, bg = t and "none" or bg_winline },
    f_wl_dirpath_sep = { fg = c.fg0, bg = t and "none" or bg_winline },
    f_wl_dirpath_text = { fg = c.blue, bg = t and "none" or bg_winline },
    f_wl_filename_text = { fg = c.orange, bg = t and "none" or bg_winline },
    f_wl_indicator = { fg = c.orange, bg = t and "none" or bg_winline },
    f_wl_lsp_icon = { fg = c.neutral_purple, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Array = { fg = c.blue, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Boolean = { fg = c.orange, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Class = { fg = c.neutral_aqua, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Color = { fg = c.fg0, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Constant = { fg = c.orange, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Constructor = { fg = c.blue, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Enum = { fg = c.blue, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_EnumMember = { fg = c.neutral_purple, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Event = { fg = c.yellow, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Field = { fg = c.red, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_File = { fg = c.fg0, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Folder = { fg = c.fg0, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Function = { fg = c.blue, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Identifier = { fg = c.red, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Interface = { fg = c.green, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Key = { fg = c.red, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Keyword = { fg = c.fg0, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Method = { fg = c.blue, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Module = { fg = c.yellow, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Namespace = { fg = c.neutral_aqua, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Null = { fg = c.aqua, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Number = { fg = c.orange, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Object = { fg = c.neutral_purple, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Operator = { fg = c.fg0, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Package = { fg = c.green, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Property = { fg = c.red, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Reference = { fg = c.fg0, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Snippet = { fg = c.red, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_String = { fg = c.green, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Struct = { fg = c.neutral_purple, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Structure = { fg = c.neutral_purple, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Text = { fg = c.green, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Type = { fg = c.yellow, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_TypeParameter = { fg = c.red, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Unit = { fg = c.neutral_purple, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Value = { fg = c.aqua, bg = t and "none" or bg_winline },
    f_wl_lsp_icon_Variable = { fg = c.neutral_purple, bg = t and "none" or bg_winline },
    f_wl_lsp_sep = { fg = c.grey, bg = t and "none" or bg_winline },
    f_wl_lsp_text = { fg = c.grey, bg = t and "none" or bg_winline },
  }
  return hlgroup_map
end

return gen_hlgroup_map
