---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    NavicIconsArray = { fg = c.blue, bg = c.bg_statusline },
    NavicIconsBoolean = { fg = c.orange, bg = c.bg_statusline },
    NavicIconsClass = { fg = c.teal, bg = c.bg_statusline },
    NavicIconsColor = { fg = c.white, bg = c.bg_statusline },
    NavicIconsConstant = { fg = c.base09, bg = c.bg_statusline },
    NavicIconsConstructor = { fg = c.blue, bg = c.bg_statusline },
    NavicIconsEnum = { fg = c.blue, bg = c.bg_statusline },
    NavicIconsEnumMember = { fg = c.purple, bg = c.bg_statusline },
    NavicIconsEvent = { fg = c.yellow, bg = c.bg_statusline },
    NavicIconsField = { fg = c.base08, bg = c.bg_statusline },
    NavicIconsFile = { fg = c.base07, bg = c.bg_statusline },
    NavicIconsFolder = { fg = c.base07, bg = c.bg_statusline },
    NavicIconsFunction = { fg = c.base0D, bg = c.bg_statusline },
    NavicIconsIdentifier = { fg = c.base08, bg = c.bg_statusline },
    NavicIconsInterface = { fg = c.green, bg = c.bg_statusline },
    NavicIconsKey = { fg = c.red, bg = c.bg_statusline },
    NavicIconsKeyword = { fg = c.base07, bg = c.bg_statusline },
    NavicIconsMethod = { fg = c.base0D, bg = c.bg_statusline },
    NavicIconsModule = { fg = c.base0A, bg = c.bg_statusline },
    NavicIconsNamespace = { fg = c.teal, bg = c.bg_statusline },
    NavicIconsNull = { fg = c.cyan, bg = c.bg_statusline },
    NavicIconsNumber = { fg = c.pink, bg = c.bg_statusline },
    NavicIconsObject = { fg = c.base0E, bg = c.bg_statusline },
    NavicIconsOperator = { fg = c.base05, bg = c.bg_statusline },
    NavicIconsPackage = { fg = c.green, bg = c.bg_statusline },
    NavicIconsProperty = { fg = c.base08, bg = c.bg_statusline },
    NavicIconsReference = { fg = c.base05, bg = c.bg_statusline },
    NavicIconsSnippet = { fg = c.red, bg = c.bg_statusline },
    NavicIconsString = { fg = c.green, bg = c.bg_statusline },
    NavicIconsStruct = { fg = c.base0E, bg = c.bg_statusline },
    NavicIconsStructure = { fg = c.base0E, bg = c.bg_statusline },
    NavicIconsText = { fg = c.base0B, bg = c.bg_statusline },
    NavicIconsType = { fg = c.base0A, bg = c.bg_statusline },
    NavicIconsTypeParameter = { fg = c.base08, bg = c.bg_statusline },
    NavicIconsUnit = { fg = c.base0E, bg = c.bg_statusline },
    NavicIconsValue = { fg = c.cyan, bg = c.bg_statusline },
    NavicIconsVariable = { fg = c.base0E, bg = c.bg_statusline },
    NavicSeparator = { fg = c.red, bg = c.bg_statusline },
    NavicText = { fg = c.light_grey, bg = c.bg_statusline },
  }
end

return gen_hlgroup
