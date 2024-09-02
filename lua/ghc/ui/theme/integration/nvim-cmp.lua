---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  ---@diagnostic disable-next-line: unused-local
  local m = params.scheme.mode ---@type fml.enums.theme.Mode
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  ---@type string
  local item_kind_bg =
    --(m == "darken" and eve.color.change_hex_lightness(c.black2, 6)) or
    --(m == "lighten" and eve.color.change_hex_lightness(c.black2, -6)) or
    "none"

  return {
    CmpBorder = { fg = c.grey_fg },
    CmpDoc = { bg = c.darker_black },
    CmpDocBorder = { fg = c.grey_fg, bg = c.darker_black },
    CmpGhostText = { link = "Comment", default = true },
    CmpItemAbbr = { fg = c.white },
    CmpItemAbbrMatch = { fg = c.blue, bold = true },
    CmpItemKindClass = { fg = c.teal, bg = item_kind_bg },
    CmpItemKindCodeium = { fg = c.vibrant_green, bg = item_kind_bg },
    CmpItemKindColor = { fg = c.white, bg = item_kind_bg },
    CmpItemKindConstant = { fg = c.base09, bg = item_kind_bg },
    CmpItemKindConstructor = { fg = c.blue, bg = item_kind_bg },
    CmpItemKindCopilot = { fg = c.green, bg = item_kind_bg },
    CmpItemKindEnum = { fg = c.blue, bg = item_kind_bg },
    CmpItemKindEnumMember = { fg = c.purple, bg = item_kind_bg },
    CmpItemKindEvent = { fg = c.yellow, bg = item_kind_bg },
    CmpItemKindField = { fg = c.base08, bg = item_kind_bg },
    CmpItemKindFile = { fg = c.base07, bg = item_kind_bg },
    CmpItemKindFolder = { fg = c.base07, bg = item_kind_bg },
    CmpItemKindFunction = { fg = c.base0D, bg = item_kind_bg },
    CmpItemKindIdentifier = { fg = c.base08, bg = item_kind_bg },
    CmpItemKindInterface = { fg = c.green, bg = item_kind_bg },
    CmpItemKindKeyword = { fg = c.base07, bg = item_kind_bg },
    CmpItemKindMethod = { fg = c.base0D, bg = item_kind_bg },
    CmpItemKindModule = { fg = c.base0A, bg = item_kind_bg },
    CmpItemKindOperator = { fg = c.base05, bg = item_kind_bg },
    CmpItemKindProperty = { fg = c.base08, bg = item_kind_bg },
    CmpItemKindReference = { fg = c.base05, bg = item_kind_bg },
    CmpItemKindSnippet = { fg = c.red, bg = item_kind_bg },
    CmpItemKindStruct = { fg = c.base0E, bg = item_kind_bg },
    CmpItemKindStructure = { fg = c.base0E, bg = item_kind_bg },
    CmpItemKindTabNine = { fg = c.baby_pink, bg = item_kind_bg },
    CmpItemKindText = { fg = c.base0B, bg = item_kind_bg },
    CmpItemKindType = { fg = c.base0A, bg = item_kind_bg },
    CmpItemKindTypeParameter = { fg = c.base08, bg = item_kind_bg },
    CmpItemKindUnit = { fg = c.base0E, bg = item_kind_bg },
    CmpItemKindValue = { fg = c.cyan, bg = item_kind_bg },
    CmpItemKindVariable = { fg = c.base0E, bg = item_kind_bg },
    CmpItemMenu = { fg = c.light_grey, italic = true },
    CmpPmenu = { bg = c.black2 },
    CmpSel = { link = "PmenuSel", bold = true },
  }
end

return gen_hlgroup_map
