---@param module_name                   string
---@return unknown
local function hmr(module_name)
  local devmode = eve.context.state.flight.devmode:snapshot() ---@type boolean
  if devmode then
    package.loaded[module_name] = nil
  end
  return require(module_name)
end

return hmr
