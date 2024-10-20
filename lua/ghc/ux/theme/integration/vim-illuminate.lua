---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
---@diagnostic disable-next-line: unused-local
local function gen_hlgroup_map(context)
  return {
    IlluminatedWordRead = { link = "LspReferenceRead" },
    IlluminatedWordText = { link = "LspReferenceText" },
    IlluminatedWordWrite = { link = "LspReferenceWrite" },
  }
end

return gen_hlgroup_map
