---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  ---@diagnostic disable-next-line: unused-local
  local m = params.scheme.mode ---@type fml.enums.theme.Mode
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

  ---@type string
  local item_kind_bg =
    --(m == "darken" and eve.color.change_hex_lightness(c.black, 6)) or
    --(m == "lighten" and eve.color.change_hex_lightness(c.black, -6)) or
    "none"

  return {
    CmpBorder = { fg = c.grey },
    CmpDoc = { bg = c.dark_black },
    CmpDocBorder = { fg = c.grey, bg = c.dark_black },
    CmpGhostText = { link = "Comment", default = true },
    CmpItemAbbr = { fg = c.fg0 },
    CmpItemAbbrMatch = { fg = c.blue, bold = true },
    CmpItemKindClass = { fg = c.cyan, bg = item_kind_bg },
    CmpItemKindCodeium = { fg = c.green, bg = item_kind_bg },
    CmpItemKindColor = { fg = c.fg0, bg = item_kind_bg },
    CmpItemKindConstant = { fg = c.dark_yellow, bg = item_kind_bg },
    CmpItemKindConstructor = { fg = c.blue, bg = item_kind_bg },
    CmpItemKindCopilot = { fg = c.green, bg = item_kind_bg },
    CmpItemKindEnum = { fg = c.blue, bg = item_kind_bg },
    CmpItemKindEnumMember = { fg = c.purple, bg = item_kind_bg },
    CmpItemKindEvent = { fg = c.yellow, bg = item_kind_bg },
    CmpItemKindField = { fg = c.red, bg = item_kind_bg },
    CmpItemKindFile = { fg = c.fg0, bg = item_kind_bg },
    CmpItemKindFolder = { fg = c.fg0, bg = item_kind_bg },
    CmpItemKindFunction = { fg = c.blue, bg = item_kind_bg },
    CmpItemKindIdentifier = { fg = c.red, bg = item_kind_bg },
    CmpItemKindInterface = { fg = c.green, bg = item_kind_bg },
    CmpItemKindKeyword = { fg = c.fg0, bg = item_kind_bg },
    CmpItemKindMethod = { fg = c.blue, bg = item_kind_bg },
    CmpItemKindModule = { fg = c.yellow, bg = item_kind_bg },
    CmpItemKindOperator = { fg = c.fg0, bg = item_kind_bg },
    CmpItemKindProperty = { fg = c.red, bg = item_kind_bg },
    CmpItemKindReference = { fg = c.fg0, bg = item_kind_bg },
    CmpItemKindSnippet = { fg = c.red, bg = item_kind_bg },
    CmpItemKindStruct = { fg = c.purple, bg = item_kind_bg },
    CmpItemKindStructure = { fg = c.purple, bg = item_kind_bg },
    CmpItemKindTabNine = { fg = c.pink, bg = item_kind_bg },
    CmpItemKindText = { fg = c.green, bg = item_kind_bg },
    CmpItemKindType = { fg = c.yellow, bg = item_kind_bg },
    CmpItemKindTypeParameter = { fg = c.red, bg = item_kind_bg },
    CmpItemKindUnit = { fg = c.purple, bg = item_kind_bg },
    CmpItemKindValue = { fg = c.cyan, bg = item_kind_bg },
    CmpItemKindVariable = { fg = c.purple, bg = item_kind_bg },
    CmpItemMenu = { fg = c.grey, italic = true },
    CmpPmenu = { bg = c.bg1 },
    CmpSel = { link = "PmenuSel", bold = true },
  }
end

return gen_hlgroup_map
