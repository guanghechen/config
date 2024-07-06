---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    DevIconc = { fg = c.blue },
    DevIconcss = { fg = c.blue },
    DevIconDart = { fg = c.cyan },
    DevIcondeb = { fg = c.cyan },
    DevIconDockerfile = { fg = c.cyan },
    DevIconhtml = { fg = c.baby_pink },
    DevIconJava = { fg = c.orange },
    DevIconjpeg = { fg = c.dark_purple },
    DevIconjpg = { fg = c.dark_purple },
    DevIconjs = { fg = c.sun },
    DevIconJSX = { fg = c.blue },
    DevIconkt = { fg = c.orange },
    DevIconlock = { fg = c.red },
    DevIconlua = { fg = c.blue },
    DevIconMd = { fg = c.blue },
    DevIconmp3 = { fg = c.white },
    DevIconmp4 = { fg = c.white },
    DevIconout = { fg = c.white },
    DevIconpng = { fg = c.dark_purple },
    DevIconpy = { fg = c.cyan },
    DevIconrb = { fg = c.pink },
    DevIconrpm = { fg = c.orange },
    DevIconSvelte = { fg = c.red },
    DevIcontoml = { fg = c.blue },
    DevIconts = { fg = c.teal },
    DevIconTSX = { fg = c.blue },
    DevIconttf = { fg = c.white },
    DevIconvue = { fg = c.vibrant_green },
    DevIconwoff = { fg = c.white },
    DevIconwoff2 = { fg = c.white },
    DevIconxz = { fg = c.sun },
    DevIconZig = { fg = c.orange },
    DevIconzip = { fg = c.sun },
  }
end

return gen_hlgroup
