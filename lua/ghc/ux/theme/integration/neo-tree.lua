---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  ---@class ghc.ux.theme.integration.tabline.hlgroups : table<string, t.fml.ux.theme.IHlgroup>
  local hlgroup_map = {
    NeoTreeDirectoryIcon = { link = "Directory" },
    NeoTreeDirectoryName = { fg = c.blue },
    NeoTreeRootName = { fg = c.orange, bold = true },
  }
  return hlgroup_map
end

return gen_hlgroup_map
