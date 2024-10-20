---@param params                        t.ghc.ux.theme.IGenHlgroupMapParams
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type t.fml.ux.theme.IPalette

  ---@class ghc.ux.theme.integration.tabline.hlgroups : table<string, t.fml.ux.theme.IHlgroup>
  local hlgroup_map = {
    NeoTreeDirectoryIcon = { fg = c.dark_blue },
    NeoTreeDirectoryName = { fg = c.blue },
    NeoTreeRootName = { fg = c.dark_yellow, bold = true },
  }
  return hlgroup_map
end

return gen_hlgroup_map
