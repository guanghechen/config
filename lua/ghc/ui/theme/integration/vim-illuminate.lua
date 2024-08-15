---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
---@diagnostic disable-next-line: unused-local
local function gen_hlgroup_map(params)
  return {
    IlluminatedWordText = { bold = true, underline = true },
    IlluminatedWordRead = { bold = true, underline = true },
    IlluminatedWordWrite = { bold = true, underline = true },
  }
end

return gen_hlgroup_map
