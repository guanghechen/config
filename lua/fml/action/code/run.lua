local __module_name__ = "fml.action.code" ---@type string

local fn = require("eve.builtin.fn")
local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")

---@class fml.action.code.IRunner
---@field public run                    fun(filepath: string, force: boolean): nil

---@class fml.action.code.IRunners
---@field public lua                    fml.action.code.IRunner

---@type fml.action.code.IRunners
local runners = {
  lua = {
    run = function(filepath)
      vim.cmd("luafile " .. filepath)
    end,
  },
  md = {
    run = function(filepath, force)
      local url = "http://localhost:9527/api/file-switch?filepath="
        .. fn.escape_url_component(filepath)
        .. "&force="
        .. (force and "true" or "false")
      vim.system({ "curl", "-X", "POST", url }, { detach = true })
    end,
  },
}

---@class fml.action.code
local M = {}

---@param context                       eve.command.IContext
---@param force                         boolean
---@return nil
function M.run(context, force)
  local bufnr = context.bufnr ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local extname = path.extname(filepath) ---@type string
  local key = extname:sub(2) ---@type string

  local runner = runners[key]
  if runner == nil then
    reporter.warn({
      from = __module_name__,
      subject = "run",
      message = "Cannot find the runner by the given filepath.",
      details = { filepath = filepath, force = force, extname = extname, key = key },
    })
    return
  end

  runner.run(filepath, force)
end

return M
