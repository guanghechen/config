---@param hlconfig                      fml.types.api.highlight.IHighlightConfig
---@param palette                       fml.types.api.highlight.IPalette
---@return vim.api.keyset.highlight
local function resolve_hlgroup(hlconfig, palette)
  ---@diagnostic disable-next-line: assign-type-mismatch
  local hlgroup = vim.deepcopy(hlconfig) ---@type vim.api.keyset.highlight

  if hlconfig.fg ~= nil then
    hlgroup.fg = palette.colors[hlconfig.fg] or hlconfig.fg
  end

  if hlconfig.bg ~= nil then
    hlgroup.bg = palette.colors[hlconfig.bg] or hlconfig.bg
  end

  if hlconfig.sp ~= nil then
    hlgroup.sp = palette.colors[hlconfig.sp] or hlconfig.sp
  end
  return hlgroup
end

return resolve_hlgroup