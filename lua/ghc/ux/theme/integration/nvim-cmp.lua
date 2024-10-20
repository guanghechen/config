---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  ---@diagnostic disable-next-line: unused-local
  local m = context.scheme.mode ---@type t.eve.e.ThemeMode
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  ---@type string
  local item_kind_bg =
    --(m == "dark" and eve.color.change_hex_lightness(c.black, 6)) or
    --(m == "light" and eve.color.change_hex_lightness(c.black, -6)) or
    "none"

  return {
    CmpBorder = { fg = c.grey },
    CmpDoc = { bg = c.bg0_h },
    CmpDocBorder = { fg = c.grey, bg = c.bg0_h },
    CmpGhostText = { link = "Comment", default = true },
    CmpItemAbbr = { fg = c.fg0 },
    CmpItemAbbrMatch = { fg = c.blue, bold = true },
    CmpItemKindClass = { fg = c.aqua, bg = item_kind_bg },
    CmpItemKindCodeium = { fg = c.green, bg = item_kind_bg },
    CmpItemKindColor = { fg = c.fg0, bg = item_kind_bg },
    CmpItemKindConstant = { fg = c.orange, bg = item_kind_bg },
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
    CmpItemKindTabNine = { fg = c.orange, bg = item_kind_bg },
    CmpItemKindText = { fg = c.green, bg = item_kind_bg },
    CmpItemKindType = { fg = c.yellow, bg = item_kind_bg },
    CmpItemKindTypeParameter = { fg = c.red, bg = item_kind_bg },
    CmpItemKindUnit = { fg = c.purple, bg = item_kind_bg },
    CmpItemKindValue = { fg = c.aqua, bg = item_kind_bg },
    CmpItemKindVariable = { fg = c.purple, bg = item_kind_bg },
    CmpItemMenu = { fg = c.grey, italic = true },
    CmpPmenu = { bg = c.bg1 },
    CmpSel = { link = "PmenuSel", bold = true },
  }
end

return gen_hlgroup_map
