---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    DapBreakpoint = { fg = c.red },
    DapBreakpointCondition = { fg = c.yellow },
    DapLogPoint = { fg = c.cyan },
    DapStopped = { fg = c.baby_pink },
  }
end

return gen_hlgroup_map
