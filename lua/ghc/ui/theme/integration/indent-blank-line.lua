---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

  return {
    IblChar = { fg = c.fg3 },
    IblScopeChar = { fg = c.grey },
    ["@ibl.scope.underline.1"] = { bg = c.bg1 },
  }
end

return gen_hlgroup_map
