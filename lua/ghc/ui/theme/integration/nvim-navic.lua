---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    NavicIconsArray = { fg = c.blue, bg = c.statusline_bg },
    NavicIconsBoolean = { fg = c.orange, bg = c.statusline_bg },
    NavicIconsClass = { fg = c.teal, bg = c.statusline_bg },
    NavicIconsColor = { fg = c.white, bg = c.statusline_bg },
    NavicIconsConstant = { fg = c.base09, bg = c.statusline_bg },
    NavicIconsConstructor = { fg = c.blue, bg = c.statusline_bg },
    NavicIconsEnum = { fg = c.blue, bg = c.statusline_bg },
    NavicIconsEnumMember = { fg = c.purple, bg = c.statusline_bg },
    NavicIconsEvent = { fg = c.yellow, bg = c.statusline_bg },
    NavicIconsField = { fg = c.base08, bg = c.statusline_bg },
    NavicIconsFile = { fg = c.base07, bg = c.statusline_bg },
    NavicIconsFolder = { fg = c.base07, bg = c.statusline_bg },
    NavicIconsFunction = { fg = c.base0D, bg = c.statusline_bg },
    NavicIconsIdentifier = { fg = c.base08, bg = c.statusline_bg },
    NavicIconsInterface = { fg = c.green, bg = c.statusline_bg },
    NavicIconsKey = { fg = c.red, bg = c.statusline_bg },
    NavicIconsKeyword = { fg = c.base07, bg = c.statusline_bg },
    NavicIconsMethod = { fg = c.base0D, bg = c.statusline_bg },
    NavicIconsModule = { fg = c.base0A, bg = c.statusline_bg },
    NavicIconsNamespace = { fg = c.teal, bg = c.statusline_bg },
    NavicIconsNull = { fg = c.cyan, bg = c.statusline_bg },
    NavicIconsNumber = { fg = c.pink, bg = c.statusline_bg },
    NavicIconsObject = { fg = c.base0E, bg = c.statusline_bg },
    NavicIconsOperator = { fg = c.base05, bg = c.statusline_bg },
    NavicIconsPackage = { fg = c.green, bg = c.statusline_bg },
    NavicIconsProperty = { fg = c.base08, bg = c.statusline_bg },
    NavicIconsReference = { fg = c.base05, bg = c.statusline_bg },
    NavicIconsSnippet = { fg = c.red, bg = c.statusline_bg },
    NavicIconsString = { fg = c.green, bg = c.statusline_bg },
    NavicIconsStruct = { fg = c.base0E, bg = c.statusline_bg },
    NavicIconsStructure = { fg = c.base0E, bg = c.statusline_bg },
    NavicIconsText = { fg = c.base0B, bg = c.statusline_bg },
    NavicIconsType = { fg = c.base0A, bg = c.statusline_bg },
    NavicIconsTypeParameter = { fg = c.base08, bg = c.statusline_bg },
    NavicIconsVariable = { fg = c.base0E, bg = c.statusline_bg },
    NavicIconsUnit = { fg = c.base0E, bg = c.statusline_bg },
    NavicIconsValue = { fg = c.cyan, bg = c.statusline_bg },
    NavicSeparator = { fg = c.red, bg = c.statusline_bg },
    NavicText = { fg = c.light_grey, bg = c.statusline_bg },
  }
end

return gen_hlgroup
