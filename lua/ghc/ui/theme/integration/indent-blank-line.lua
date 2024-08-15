---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    IblChar = { fg = c.line },
    IblScopeChar = { fg = c.grey },
    ["@ibl.scope.underline.1"] = { bg = c.black2 },
  }
end

return gen_hlgroup_map
