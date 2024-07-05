---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  return {
    IlluminatedWordText = { bold = true, reverse = true },
    IlluminatedWordRead = { bold = true, reverse = true },
    IlluminatedWordWrite = { bold = true, reverse = true },
  }
end

return gen_hlgroup
