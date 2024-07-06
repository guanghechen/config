---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
---@diagnostic disable-next-line: unused-local
local function gen_hlgroup(params)
  return {
    IlluminatedWordText = { bold = true, underline = true },
    IlluminatedWordRead = { bold = true, underline = true },
    IlluminatedWordWrite = { bold = true, underline = true },
  }
end

return gen_hlgroup
