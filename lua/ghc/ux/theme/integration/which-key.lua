---@param params                        t.ghc.ux.theme.IGenHlgroupMapParams
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    WhichKey = { fg = c.blue },
    WhichKeyDesc = { fg = c.red },
    WhichKeyGroup = { fg = c.green },
    WhichKeySeparator = { fg = c.grey },
    WhichKeyValue = { fg = c.green },
  }
end

return gen_hlgroup_map
