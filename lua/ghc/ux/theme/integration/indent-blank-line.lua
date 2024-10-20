---@param params                        t.ghc.ux.theme.IGenHlgroupMapParams
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    IblChar = { fg = c.fg3 },
    IblScopeChar = { fg = c.grey },
    ["@ibl.scope.underline.1"] = { bg = c.bg1 },
  }
end

return gen_hlgroup_map
