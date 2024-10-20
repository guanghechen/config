---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    IblChar = { fg = c.fg3 },
    IblScopeChar = { fg = c.grey },
    ["@ibl.scope.underline.1"] = { bg = c.bg1 },
  }
end

return gen_hlgroup_map
