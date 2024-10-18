---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

  return {
    TreesitterContext = { fg = c.fg0, bg = c.bg3 },
    TreesitterContextBottom = {},
    TreesitterContextLineNumber = { fg = c.pink },
    TreesitterContextLineNumberBottom = { underline = true },
  }
end

return gen_hlgroup_map
