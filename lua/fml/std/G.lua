local reporter = require("fml.std.reporter")

local id = 0 ---@type integer
local gfn = {} ---@type table<string, fun(): nil>

---@class fml.std.G
local M = {}
setmetatable(M, { __index = gfn })

---@param fn_name                       string
---@param callback                      fun(): nil
---@return string|nil
function M.register_known_fn(fn_name, callback)
  if type(callback) ~= "function" then
    reporter.error({
      from = "fml.std.G",
      subject = "add_anonymous_fn",
      message = "Expect a function but got " .. type(callback),
      details = { callback = callback },
    })
    return nil
  end

  gfn[fn_name] = function()
    callback()
  end
  return fn_name
end

---@param fn                       fun(args?: string): nil
---@return string|nil
function M.register_anonymous_fn(fn)
  if type(fn) ~= "function" then
    reporter.error({
      from = "fml.std.G",
      subject = "add_anonymous_fn",
      message = "Expect a function but got " .. type(fn),
      details = { callback = fn },
    })
    return nil
  end

  id = id + 1
  local fn_name = "_" .. id
  gfn[fn_name] = fn
  return fn_name
end

return M
