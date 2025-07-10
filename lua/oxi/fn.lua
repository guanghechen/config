local __module_name__ = "oxi.fn" ---@type string

---@class oxi.fn.ICmdResult
---@field public cmd                    string
---@field public error                  ?string
---@field public data                   ?any

---@class oxi.fn.IFunResult
---@field public error                  ?string
---@field public data                   ?any

---@class oxi.fn
local M = {}

---@param subject                       string
---@param result_str                    string
---@return boolean
---@return any|nil
---@return string|nil
function M.resolve_cmd_result(subject, result_str)
  local result = std.json.parse(result_str)
  if result == nil or type(result.error) == "string" then
    std.reporter.error({
      from = __module_name__,
      subject = subject,
      message = "Failed to run command.",
      details = (result or {}).error or result,
    })
    return false
  end

  ---@cast result                       oxi.fn.ICmdResult
  return true, result.data, result.cmd
end

---@param subject                       string
---@param result_str                    string
---@return boolean
---@return any|nil
function M.resolve_fun_result(subject, result_str)
  local result = std.json.parse(result_str)
  if result == nil or type(result.error) == "string" then
    std.reporter.error({
      from = __module_name__,
      subject = subject,
      message = "Failed to run function",
      details = (result or {}).error or result,
    })
    return false, nil
  end

  ---@cast result                       oxi.fn.IFunResult
  return true, result.data
end

---@param subject                       string
---@param fn                            fun(...): string
---@param args                          any
---@return boolean
---@return any|nil
function M.run_cmd(subject, fn, args)
  local result_str = fn(args) ---@type string
  return M.resolve_cmd_result(subject, result_str)
end

---@param subject                       string
---@param fn                            fun(...): string
---@param ...                           any
---@return boolean
---@return any|nil
function M.run_fun(subject, fn, ...)
  local ok, result = pcall(fn, ...)
  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = subject,
      message = "Failed to run function",
      details = { error = result },
    })
    return false, nil
  end
  return M.resolve_fun_result(subject, result)
end

return M
