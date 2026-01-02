local id = 0 ---@type integer
local gfn = {} ---@type table<string, fun(...): nil>

---@class dot.G
local M = {}
setmetatable(M, { __index = gfn })

M.noop = stl.fn.noop

---@param fn                            fun(...): nil
---@param fn_name                       string|nil
---@return string
---@return fun(): nil
function M.register_anonymous_fn(fn, fn_name)
  if fn_name == nil then
    id = id + 1
    fn_name = "_" .. id
  end

  gfn[fn_name] = fn

  local unregister = function()
    gfn[fn_name] = nil
  end

  return "dot.G." .. fn_name, unregister
end

return M
