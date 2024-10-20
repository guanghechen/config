---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    NotifyDEBUGBorder = { fg = c.blue },
    NotifyDEBUGIcon = { fg = c.blue },
    NotifyDEBUGTitle = { fg = c.blue },
    NotifyERRORBorder = { fg = c.red },
    NotifyERRORIcon = { fg = c.red },
    NotifyERRORTitle = { fg = c.red },
    NotifyINFOBorder = { fg = c.green },
    NotifyINFOIcon = { fg = c.green },
    NotifyINFOTitle = { fg = c.green },
    NotifyTRACEBorder = { fg = c.blue },
    NotifyTRACEIcon = { fg = c.purple },
    NotifyTRACETitle = { fg = c.purple },
    NotifyWARNBorder = { fg = c.purple },
    NotifyWARNIcon = { fg = c.yellow },
    NotifyWARNTitle = { fg = c.yellow },
  }
end

return gen_hlgroup_map
