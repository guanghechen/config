local reporter = require("fc.std.reporter")

local id = 0 ---@type integer
local gfn = {} ---@type table<string, fun(...): nil>

---@class fc.std.G
local M = {}
setmetatable(M, { __index = gfn })

---@param fn                       fun(...): nil
---@return string|nil
function M.register_anonymous_fn(fn)
  if type(fn) ~= "function" then
    reporter.error({
      from = "fc.std.G",
      subject = "add_anonymous_fn",
      message = "Expect a function but got " .. type(fn),
      details = { callback = fn },
    })
    return nil
  end

  id = id + 1
  local fn_name = "_" .. id
  gfn[fn_name] = fn
  return "fc.G." .. fn_name
end

return M
