---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    IblChar = { fg = c.line },
    IblScopeChar = { fg = c.grey },
    ["@ibl.scope.underline.1"] = { bg = c.black2 },
  }
end

return gen_hlgroup
