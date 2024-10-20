---@param params                        t.ghc.ux.theme.IGenHlgroupMapParams
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    DapBreakpoint = { fg = c.red },
    DapBreakpointCondition = { fg = c.yellow },
    DapLogPoint = { fg = c.cyan },
    DapStopped = { fg = c.pink },
  }
end

return gen_hlgroup_map
