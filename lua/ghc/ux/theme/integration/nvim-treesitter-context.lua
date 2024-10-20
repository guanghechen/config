---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    TreesitterContext = { fg = c.fg0, bg = c.bg3 },
    TreesitterContextBottom = {},
    TreesitterContextLineNumber = { fg = c.orange },
    TreesitterContextLineNumberBottom = { underline = true },
  }
end

return gen_hlgroup_map
