local id = 0 ---@type integer
local gfn = {} ---@type table<string, fun(...): nil>

---@class eve.std.G
local M = {}
setmetatable(M, { __index = gfn })

---@param fn                       fun(...): nil
---@return string
function M.register_anonymous_fn(fn)
  id = id + 1
  local fn_name = "_" .. id
  gfn[fn_name] = fn
  return "eve.G." .. fn_name
end

return M
