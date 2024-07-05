---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    NotifyDEBUGBorder = { fg = c.grey },
    NotifyDEBUGIcon = { fg = c.grey },
    NotifyDEBUGTitle = { fg = c.grey },
    NotifyERRORBorder = { fg = c.red },
    NotifyERRORIcon = { fg = c.red },
    NotifyERRORTitle = { fg = c.red },
    NotifyINFOBorder = { fg = c.green },
    NotifyINFOIcon = { fg = c.green },
    NotifyINFOTitle = { fg = c.green },
    NotifyTRACEBorder = { fg = c.purple },
    NotifyTRACEIcon = { fg = c.purple },
    NotifyTRACETitle = { fg = c.purple },
    NotifyWARNBorder = { fg = c.orange },
    NotifyWARNIcon = { fg = c.orange },
    NotifyWARNTitle = { fg = c.orange },
  }
end

return gen_hlgroup
