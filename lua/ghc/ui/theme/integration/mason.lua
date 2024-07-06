---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    MasonHeader = { fg = c.black, bg = c.red },
    MasonHeaderSecondary = { fg = c.black, bg = c.green },
    MasonHighlight = { fg = c.blue },
    MasonHighlightBlock = { fg = c.black, bg = c.green },
    MasonHighlightBlockBold = { fg = c.black, bg = c.green },
    MasonMuted = { fg = c.light_grey },
    MasonMutedBlock = { fg = c.light_grey, bg = c.one_bg },
  }
end

return gen_hlgroup
