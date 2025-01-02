local __module_name__ = "fml.action.code" ---@type string

local reporter = require("eve.builtin.reporter")

local path = require("eve.lib.path")

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

---@param context                       eve.command.IContext
---@return nil
function M.run(context)
  local bufnr = context.bufnr ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
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
