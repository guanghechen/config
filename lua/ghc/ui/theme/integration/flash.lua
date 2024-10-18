---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette
  local t = params.transparency ---@type boolean

  return {
    FlashBackdrop = { fg = c.grey, bg = "none", italic = true },
    FlashCursor = { fg = c.red, bg = t and "none" or "grey" },
    FlashLabel = { fg = c.fg0, bg = t and "none" or "grey" },
    FlashMatch = { fg = c.cyan, bg = t and "none" or "grey" },
  }
end

return gen_hlgroup_map
