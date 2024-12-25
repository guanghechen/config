local __module_name__ = "fml.action.code" ---@type string

local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")

---@class fml.action.code.IRunner
---@field public run                    fun(filepath: string): nil

---@class fml.action.code.IRunners
---@field public lua                    fml.action.code.IRunner

---@type fml.action.code.IRunners
local runners = {
  lua = {
    run = function(filepath)
      vim.cmd("luafile " .. filepath)
    end,
  },
}

---@class fml.action.code
local M = {}

---@param filepath                      string
function M.run(filepath)
  local extname = path.extname(filepath) ---@type string
  local key = extname:sub(2) ---@type string

  local runner = runners[key]
  if runner ~= nil then
    runner.run(filepath)
    reporter.warn({
      from = __module_name__,
      subject = "run",
      message = "Cannot find the runner by the given filepath.",
      details = { filepath = filepath, extname = extname },
    })
    return
  end
end

return M
