---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    MiniIconsAzure = { fg = c.blue },
    MiniIconsBlue = { fg = c.blue },
    MiniIconsCyan = { fg = c.cyan },
    MiniIconsGreen = { fg = c.green },
    MiniIconsGrey = { fg = c.grey_fg2 },
    MiniIconsOrange = { fg = c.orange },
    MiniIconsPurple = { fg = c.darker_purple },
    MiniIconsRed = { fg = c.red },
    MiniIconsYellow = { fg = c.yellow },
  }
end

return gen_hlgroup
