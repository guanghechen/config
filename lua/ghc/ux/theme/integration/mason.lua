---@param params                        t.ghc.ux.theme.IGenHlgroupMapParams
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    MasonHeader = { fg = c.black, bg = c.red },
    MasonHeaderSecondary = { fg = c.black, bg = c.green },
    MasonHighlight = { fg = c.blue },
    MasonHighlightBlock = { fg = c.black, bg = c.green },
    MasonHighlightBlockBold = { fg = c.black, bg = c.green },
    MasonMuted = { fg = c.grey },
    MasonMutedBlock = { fg = c.grey, bg = c.bg1 },
  }
end

return gen_hlgroup_map
