---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors
  local t = params.transparency ---@type boolean

  return {
    CmpBorder = { fg = c.grey_fg },
    CmpDoc = t and { fg = c.grey_fg, bg = "none" } or nil,
    CmpItemKindClass = { fg = c.teal },
    CmpItemKindCodeium = { fg = c.vibrant_green },
    CmpItemKindColor = { fg = c.white },
    CmpItemKindConstant = { fg = c.base09 },
    CmpItemKindConstructor = { fg = c.blue },
    CmpItemKindCopilot = { fg = c.green },
    CmpItemKindEnum = { fg = c.blue },
    CmpItemKindEnumMember = { fg = c.purple },
    CmpItemKindEvent = { fg = c.yellow },
    CmpItemKindField = { fg = c.base08 },
    CmpItemKindFile = { fg = c.base07 },
    CmpItemKindFolder = { fg = c.base07 },
    CmpItemKindFunction = { fg = c.base0D },
    CmpItemKindIdentifier = { fg = c.base08 },
    CmpItemKindInterface = { fg = c.green },
    CmpItemKindKeyword = { fg = c.base07 },
    CmpItemKindMethod = { fg = c.base0D },
    CmpItemKindModule = { fg = c.base0A },
    CmpItemKindOperator = { fg = c.base05 },
    CmpItemKindProperty = { fg = c.base08 },
    CmpItemKindReference = { fg = c.base05 },
    CmpItemKindSnippet = { fg = c.red },
    CmpItemKindStruct = { fg = c.base0E },
    CmpItemKindStructure = { fg = c.base0E },
    CmpItemKindTabNine = { fg = c.baby_pink },
    CmpItemKindText = { fg = c.base0B },
    CmpItemKindType = { fg = c.base0A },
    CmpItemKindTypeParameter = { fg = c.base08 },
    CmpItemKindUnit = { fg = c.base0E },
    CmpItemKindValue = { fg = c.cyan },
    CmpItemKindVariable = { fg = c.base0E },
  }
end

return gen_hlgroup
