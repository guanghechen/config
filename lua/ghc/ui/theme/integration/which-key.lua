---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

  return {
    WhichKey = { fg = c.blue },
    WhichKeyDesc = { fg = c.red },
    WhichKeyGroup = { fg = c.green },
    WhichKeySeparator = { fg = c.grey },
    WhichKeyValue = { fg = c.green },
  }
end

return gen_hlgroup_map
