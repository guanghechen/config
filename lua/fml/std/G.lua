local reporter = require("fml.std.reporter")

local id = 0 ---@type integer
local gfn = {} ---@type table<string, fun(): nil>

---@class fml.std.G
local M = {}
setmetatable(M, { __index = gfn })

---@param callback                       fun(): nil
---@return string|nil
function M.add_anonymous_fn(callback)
  if type(callback) ~= "function" then
    reporter.error({
      from = "fml.std.G",
      subject = "add_anonymous_fn",
      message = "Expect a function but got " .. type(callback),
      details = { callback = callback },
    })
  end

  id = id + 1
  local fn_name = "_" .. id
  gfn[fn_name] = function()
    callback()
  end
  return fn_name
end

return M
