local __module_name__ = "oxi.fn" ---@type string

---@class oxi.fn.IFunResult
---@field public error                  ?string
---@field public data                   ?any

---@class oxi.fn
local M = {}

---@param text                          string
---@return string
function M.md5(text)
  local nvim_tools = require("nvim_tools")
  return nvim_tools.md5(text)
end

---@return integer
function M.now()
  local nvim_tools = require("nvim_tools")
  return nvim_tools.now()
end

---@return string
function M.uuid()
  local nvim_tools = require("nvim_tools")
  return nvim_tools.uuid()
end

---@param method                        string
---@param ...                           any
---@return boolean
---@return any|nil
function M.safe_call(method, ...)
  local nvim_tools = require("nvim_tools")
  local ok, result = pcall(nvim_tools[method], ...)
  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = string.format("[safe_call] failed on calling nvim_tools.%s", method),
      details = {
        args = { ... },
        error = result,
        method = method,
      },
    })
    return false, nil
  end

  if result == nil or type(result.error) == "string" then
    result = result or {}
    local err = result.error or result ---@type unknown|nil

    std.reporter.error({
      from = __module_name__,
      subject = string.format("[safe_call] failed on calling nvim_tools.%s", method),
      details = {
        args = { ... },
        error = err,
        method = method,
      },
    })
    return false, nil
  end

  return true, result.data
end

---@param method                        string
---@param ...                           any
---@return any|nil
---@return string|nil
function M.safe_execute(method, ...)
  local nvim_tools = require("nvim_tools")
  local ok, result = pcall(nvim_tools[method], ...)
  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = string.format("[safe_execute] failed on calling nvim_tools.%s", method),
      details = {
        args = { ... },
        error = result,
        method = method,
      },
    })
    return nil, nil
  end

  if result == nil or type(result.error) == "string" then
    result = result or {}
    local cmd = result.cmd ---@type string|nil
    local err = result.error or result ---@type unknown|nil

    std.reporter.error({
      from = __module_name__,
      subject = string.format("[safe_execute] failed on calling nvim_tools.%s", method),
      details = {
        args = { ... },
        cmd = cmd,
        error = err,
        method = method,
      },
    })
    return nil
  end

  return result.data, result.cmd
end

---@param method                        string
---@param ...                           any
---@return any|nil
function M.safe_run(method, ...)
  local nvim_tools = require("nvim_tools")
  local ok, result = pcall(nvim_tools[method], ...)
  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = string.format("[safe_run] failed on calling nvim_tools.%s", method),
      details = {
        args = { ... },
        error = result,
        method = method,
      },
    })
    return nil
  end
  return result
end

return M
