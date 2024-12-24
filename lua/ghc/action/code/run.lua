local __module_name__ = "ghc.action.code" ---@type string

local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")

---@class ghc.action.code.IRunner
---@field public run                    fun(filepath: string): nil

---@class ghc.action.code.IRunners
---@field public lua                    ghc.action.code.IRunner

---@type ghc.action.code.IRunners
local runners = {
  lua = {
    run = function(filepath)
      vim.cmd("luafile " .. filepath)
    end,
  },
}

---@class ghc.action.code
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
