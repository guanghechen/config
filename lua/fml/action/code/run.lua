local __module_name__ = "fml.action.code" ---@type string

local state = require("eve.state")
local Terminal = require("fml.ux.terminal")

local code_runner_terminals = {} ---@type table<string, fml.ux.ITerminal>

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
        .. eve.std.string.escape_url_component(filepath)
        .. "&force="
        .. (force and "true" or "false")
      vim.system({ "curl", "-X", "POST", url }, { detach = true })
    end,
  },
  mjs = {
    run = function(filepath)
      ---@param terminal                fml.ux.ITerminal
      ---@return nil
      local function handle(terminal)
        local bufnr = terminal:get_bufnr() ---@type integer|nil
        if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
          local channel_id = vim.bo[bufnr].channel ---@type integer
          local cmd = "node " .. vim.fn.shellescape(filepath) .. "\n" ---@type string
          vim.fn.chansend(channel_id, cmd)
        end
      end

      local terminal = code_runner_terminals.mjs ---@type fml.ux.ITerminal|nil
      if terminal == nil then
        terminal = Terminal.new({
          cwd = eve.path.cwd(),
          permanent = false,
          title = "code run (mjs)",
        })
        code_runner_terminals.mjs = terminal

        terminal:show()
        vim.defer_fn(function()
          handle(terminal)
        end, 1500)
      else
        terminal:show()
        vim.defer_fn(function()
          handle(terminal)
        end, 100)
      end
    end,
  },
}

---@class fml.action.code
local M = {}

---@param force                         boolean
---@return nil
function M.run(force)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = state.tab.get_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  local extname = eve.path.extname(filepath) ---@type string
  local key = extname:sub(2) ---@type string

  local runner = runners[key]
  if runner == nil then
    eve.reporter.warn({
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
