local state = require("eve.state")

---@param module_name                   string
local function hmr(module_name)
  local devmode = state.flight.devmode:snapshot() ---@type boolean
  if devmode then
    package.loaded[module_name] = nil
  end
  return require(module_name)
end

return hmr
