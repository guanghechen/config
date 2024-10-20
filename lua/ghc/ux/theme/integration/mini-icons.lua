---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    MiniIconsAzure = { fg = c.blue },
    MiniIconsBlue = { fg = c.blue },
    MiniIconsCyan = { fg = c.aqua },
    MiniIconsGreen = { fg = c.green },
    MiniIconsGrey = { fg = c.fg0 },
    MiniIconsOrange = { fg = c.orange },
    MiniIconsPurple = { fg = c.purple },
    MiniIconsRed = { fg = c.red },
    MiniIconsYellow = { fg = c.yellow },
  }
end

return gen_hlgroup
