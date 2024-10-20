---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette
  local t = context.transparency ---@type boolean

  return {
    FlashBackdrop = { fg = c.grey, bg = "none", italic = true },
    FlashCursor = { fg = c.red, bg = t and "none" or "grey" },
    FlashLabel = { fg = c.fg0, bg = t and "none" or "grey" },
    FlashMatch = { fg = c.aqua, bg = t and "none" or "grey" },
  }
end

return gen_hlgroup_map
