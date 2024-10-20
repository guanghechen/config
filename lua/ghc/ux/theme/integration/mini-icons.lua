---@param params                        t.ghc.ux.theme.IGenHlgroupMapParams
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup(params)
  local c = params.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    MiniIconsAzure = { fg = c.blue },
    MiniIconsBlue = { fg = c.blue },
    MiniIconsCyan = { fg = c.cyan },
    MiniIconsGreen = { fg = c.green },
    MiniIconsGrey = { fg = c.fg0 },
    MiniIconsOrange = { fg = c.pink },
    MiniIconsPurple = { fg = c.dark_purple },
    MiniIconsRed = { fg = c.red },
    MiniIconsYellow = { fg = c.yellow },
  }
end

return gen_hlgroup
