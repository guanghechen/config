---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

  ---@class ghc.ui.theme.integration.tabline.hlgroups : table<string, fml.types.ui.theme.IHlgroup>
  local hlgroup_map = {
    NeoTreeDirectoryIcon = { fg = c.dark_blue },
    NeoTreeDirectoryName = { fg = c.blue },
    NeoTreeRootName = { fg = c.dark_yellow, bold = true },
  }
  return hlgroup_map
end

return gen_hlgroup_map
