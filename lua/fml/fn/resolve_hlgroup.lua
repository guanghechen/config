---@param hlconfig                      fml.types.ui.theme.IHighlightConfig
---@param scheme                        fml.types.ui.theme.IScheme
---@return fml.types.ui.theme.IHighlightGroup
local function resolve_hlgroup(hlconfig, scheme)
  ---@diagnostic disable-next-line: assign-type-mismatch
  local hlgroup = vim.deepcopy(hlconfig) ---@type fml.types.ui.theme.IHighlightGroup

  if hlconfig.fg ~= nil then
    hlgroup.fg = scheme.colors[hlconfig.fg] or hlconfig.fg
  end

  if hlconfig.bg ~= nil then
    hlgroup.bg = scheme.colors[hlconfig.bg] or hlconfig.bg
  end

  if hlconfig.sp ~= nil then
    hlgroup.sp = scheme.colors[hlconfig.sp] or hlconfig.sp
  end
  return hlgroup
end

return resolve_hlgroup