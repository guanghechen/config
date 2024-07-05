---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    DevIconDart = { fg = c.cyan },
    DevIconDockerfile = { fg = c.cyan },
    DevIconJava = { fg = c.orange },
    DevIconJSX = { fg = c.blue },
    DevIconMd = { fg = c.blue },
    DevIconSvelte = { fg = c.red },
    DevIconTSX = { fg = c.blue },
    DevIconZig = { fg = c.orange },
    DevIconc = { fg = c.blue },
    DevIconcss = { fg = c.blue },
    DevIcondeb = { fg = c.cyan },
    DevIconhtml = { fg = c.baby_pink },
    DevIconjpeg = { fg = c.dark_purple },
    DevIconjpg = { fg = c.dark_purple },
    DevIconjs = { fg = c.sun },
    DevIconkt = { fg = c.orange },
    DevIconlock = { fg = c.red },
    DevIconlua = { fg = c.blue },
    DevIconmp3 = { fg = c.white },
    DevIconmp4 = { fg = c.white },
    DevIconout = { fg = c.white },
    DevIconpng = { fg = c.dark_purple },
    DevIconpy = { fg = c.cyan },
    DevIconrb = { fg = c.pink },
    DevIconrpm = { fg = c.orange },
    DevIcontoml = { fg = c.blue },
    DevIconts = { fg = c.teal },
    DevIconttf = { fg = c.white },
    DevIconvue = { fg = c.vibrant_green },
    DevIconwoff = { fg = c.white },
    DevIconwoff2 = { fg = c.white },
    DevIconxz = { fg = c.sun },
    DevIconzip = { fg = c.sun },
  }
end

return gen_hlgroup
