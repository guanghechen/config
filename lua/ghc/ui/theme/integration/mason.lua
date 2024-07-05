---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors
  local t = params.transparency ---@type boolean

  return {
    MasonHeader = { fg = c.black, bg = c.red },
    MasonHighlight = { fg = c.blue },
    MasonHighlightBlock = { fg = c.black, bg = c.green },
    MasonHighlightBlockBold = { link = "MasonHighlightBlock" },
    MasonHeaderSecondary = { link = "MasonHighlightBlock" },
    MasonMuted = { fg = c.light_grey },
    MasonMutedBlock = { fg = c.light_grey, bg = c.one_bg },
  }
end

return gen_hlgroup
