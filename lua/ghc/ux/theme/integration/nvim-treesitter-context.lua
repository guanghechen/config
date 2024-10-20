---@param params                        t.ghc.ux.theme.IGenHlgroupMapParams
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    TreesitterContext = { fg = c.fg0, bg = c.bg3 },
    TreesitterContextBottom = {},
    TreesitterContextLineNumber = { fg = c.pink },
    TreesitterContextLineNumberBottom = { underline = true },
  }
end

return gen_hlgroup_map
