---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return ghc.ui.theme.integration.tabline.hlgroups
local function gen_hlgroup_map(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors
  local t = params.transparency ---@type boolean

  ---@class ghc.ui.theme.integration.tabline.hlgroups : table<string, fml.types.ui.theme.IHlgroup>
  local hlgroup_map = {
    f_wl_bg = { fg = t and "none" or c.bg_winline, bg = t and "none" or c.bg_winline },
    f_wl_dirpath_text = { fg = c.darker_white, bg = t and "none" or c.bg_winline },
    f_wl_filename_text = { fg = c.darker_white, bg = t and "none" or c.bg_winline },
    f_wl_indicator = { fg = c.pink, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon = { fg = c.darker_purple, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Array = { fg = c.blue, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Boolean = { fg = c.orange, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Class = { fg = c.teal, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Color = { fg = c.white, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Constant = { fg = c.base09, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Constructor = { fg = c.blue, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Enum = { fg = c.blue, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_EnumMember = { fg = c.darker_purple, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Event = { fg = c.yellow, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Field = { fg = c.base08, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_File = { fg = c.base07, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Folder = { fg = c.base07, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Function = { fg = c.base0D, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Identifier = { fg = c.base08, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Interface = { fg = c.green, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Key = { fg = c.red, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Keyword = { fg = c.base07, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Method = { fg = c.base0D, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Module = { fg = c.base0A, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Namespace = { fg = c.teal, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Null = { fg = c.cyan, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Number = { fg = c.pink, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Object = { fg = c.darker_purple, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Operator = { fg = c.base05, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Package = { fg = c.green, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Property = { fg = c.base08, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Reference = { fg = c.base05, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Snippet = { fg = c.red, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_String = { fg = c.green, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Struct = { fg = c.darker_purple, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Structure = { fg = c.darker_purple, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Text = { fg = c.base0B, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Type = { fg = c.base0A, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_TypeParameter = { fg = c.base08, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Unit = { fg = c.darker_purple, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Value = { fg = c.cyan, bg = t and "none" or c.bg_winline },
    f_wl_lsp_icon_Variable = { fg = c.darker_purple, bg = t and "none" or c.bg_winline },
    f_wl_lsp_sep = { fg = c.darker_white, bg = t and "none" or c.bg_winline },
    f_wl_lsp_text = { fg = c.darker_white, bg = t and "none" or c.bg_winline },
  }
  return hlgroup_map
end

return gen_hlgroup_map
