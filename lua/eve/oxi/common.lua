local json = require("eve.std.json")
local reporter = require("eve.std.reporter")

---@class eve.oxi
local M = require("eve.oxi.mod")

---@class eve.oxi.ICmdResult
---@field public cmd                    string
---@field public error                  ?string
---@field public data                   ?any

---@class eve.oxi.IFunResult
---@field public error                  ?string
---@field public data                   ?any

---@param input string
---@return string
function M.normalize_comma_list(input)
  return M.nvim_tools.normalize_comma_list(input)
end

---@return integer
function M.now()
  return M.nvim_tools.now()
end

---@param from                          string
---@param result_str                    string
---@return boolean
---@return any|nil
function M.resolve_cmd_result(from, result_str)
  local result = json.parse(result_str)
  if result == nil or type(result.error) == "string" then
    reporter.error({
      from = from,
      message = "Failed to run command.",
      details = (result or {}).error or result,
    })
    return false, nil
  end

  ---@cast result eve.oxi.ICmdResult
  return true, result.data
end

---@param from                          string
---@param result_str                    string
---@return boolean
---@return any|nil
function M.resolve_fun_result(from, result_str)
  local result = json.parse(result_str)
  if result == nil or type(result.error) == "string" then
    reporter.error({
      from = from,
      message = "Failed to run function",
      details = (result or {}).error or result,
    })
    return false, nil
  end

  ---@cast result eve.oxi.IFunResult
  return true, result.data
end

---@param from                          string
---@param fn                            fun(...): string
---@param args                          any
---@return boolean
---@return any|nil
function M.run_cmd(from, fn, args)
  local result_str = fn(args) ---@type string
  return M.resolve_cmd_result(from, result_str)
end

---@param from                          string
---@param fn                            fun(...): string
---@param args                          any
---@return boolean
---@return any|nil
function M.run_fun(from, fn, args)
  local result_str = fn(args) ---@type string
  return M.resolve_fun_result(from, result_str)
end
