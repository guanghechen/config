---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    MasonHeader = { fg = c.bg0, bg = c.red },
    MasonHeaderSecondary = { fg = c.bg0, bg = c.blue },
    MasonHighlight = { fg = c.aqua },
    MasonHighlightBlock = { fg = c.bg0, bg = c.blue },
    MasonHighlightBlockBold = { fg = c.bg0, bg = c.blue, bold = true },
    MasonMuted = { fg = c.grey },
    MasonMutedBlock = { fg = c.grey, bg = c.bg1 },
  }
end

return gen_hlgroup_map
