---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    TreesitterContext = { fg = c.base07, bg = c.one_bg2 },
    TreesitterContextBottom = {},
    TreesitterContextLineNumber = { fg = c.baby_pink },
    TreesitterContextLineNumberBottom = { underline = true },
  }
end

return gen_hlgroup_map
