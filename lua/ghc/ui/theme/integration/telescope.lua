---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors
  local t = params.transparency ---@type boolean

  return {
    TelescopeBorder = t and { fg = c.grey, bg = "none" } or { fg = c.darker_black, bg = c.darker_black },
    TelescopeMatching = { bg = c.one_bg, fg = c.blue },
    TelescopeNormal = { bg = c.darker_black },
    TelescopePreviewTitle = { fg = c.black, bg = c.green },
    TelescopePromptBorder = t and { fg = c.grey, bg = "none" } or { fg = c.black2, bg = c.black2 },
    TelescopePromptNormal = { fg = c.white, bg = c.black2 },
    TelescopePromptPrefix = { fg = c.red, bg = c.black2 },
    TelescopePromptTitle = { fg = c.black, bg = c.red },
    TelescopeResultsDiffAdd = { fg = c.green },
    TelescopeResultsDiffChange = { fg = c.yellow },
    TelescopeResultsDiffDelete = { fg = c.red },
    TelescopeResultsTitle = { fg = c.darker_black, bg = c.darker_black },
    TelescopeSelection = { bg = c.black2, fg = c.white },
  }
end

return gen_hlgroup_map
