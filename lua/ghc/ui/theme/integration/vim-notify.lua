---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

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
    NotifyWARNBorder = { fg = c.yellow },
    NotifyWARNIcon = { fg = c.yellow },
    NotifyWARNTitle = { fg = c.yellow },
  }
end

return gen_hlgroup_map
