---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    WhichKey = { fg = c.blue },
    WhichKeyDesc = { fg = c.red },
    WhichKeyGroup = { fg = c.green },
    WhichKeySeparator = { fg = c.light_grey },
    WhichKeyValue = { fg = c.green },
  }
end

return gen_hlgroup
