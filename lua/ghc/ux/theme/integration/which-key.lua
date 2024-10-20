---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    WhichKey = { fg = c.blue },
    WhichKeyDesc = { fg = c.red },
    WhichKeyGroup = { fg = c.green },
    WhichKeySeparator = { fg = c.grey },
    WhichKeyValue = { fg = c.green },
  }
end

return gen_hlgroup_map
