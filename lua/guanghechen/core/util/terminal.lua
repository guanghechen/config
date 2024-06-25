-- https://github.com/LazyVim/LazyVim/blob/f086bcde253c29be9a2b9c90b413a516f5d5a3b2/lua/lazyvim/util/terminal.lua#L1

local context_session = require("guanghechen.core.context.session")

---@type table<string,LazyFloat>
local terminals = {}

---@param opts { cmd: string|string[], cwd: string, env: table|nil }
---@return string
local function calc_terminal_key(opts)
  local cmd = opts.cmd ---@type string|string[]
  local cwd = opts.cwd ---@type string
  local env = opts.env ---@type table|nil
  local termkey = vim.inspect({ cmd = cmd, cwd = cwd, env = env, count = vim.v.count1 })
  return termkey
end

---@class guanghechen.core.util.terminal
local M = {}

---@class LazyTermOpts: LazyCmdOptions
---@field interactive? boolean
---@field esc_esc? boolean
---@field ctrl_hjkl? boolean
---@field id? string

-- Opens a floating terminal (interactive by default)
---@param cmd? string[]|string
---@param opts? LazyTermOpts
function M.open_terminal(cmd, opts)
  context_session.caller_bufnr:next(vim.api.nvim_get_current_buf())
  context_session.caller_winnr:next(vim.api.nvim_get_current_win())

  opts = vim.tbl_deep_extend("force", {
    ft = "term",
    size = { width = 0.9, height = 0.9 },
    backdrop = nil,
  }, opts or {}, { persistent = true }) --[[@as LazyTermOpts]]

  local termkey = opts.id or calc_terminal_key({
    cmd = cmd or "shell",
    cwd = opts.cwd,
    env = opts.env,
  })

  if terminals[termkey] and terminals[termkey]:buf_valid() then
    terminals[termkey]:toggle()
  else
    terminals[termkey] = require("lazy.util").float_term(cmd, opts)
    local buf = terminals[termkey].buf
    vim.b[buf].lazyterm_cmd = cmd
    if opts.esc_esc == false then
      vim.keymap.set("t", "<esc>", "<esc>", { buffer = buf, nowait = true })
    end
    if opts.ctrl_hjkl == false then
      vim.keymap.set("t", "<c-h>", "<c-h>", { buffer = buf, nowait = true })
      vim.keymap.set("t", "<c-j>", "<c-j>", { buffer = buf, nowait = true })
      vim.keymap.set("t", "<c-k>", "<c-k>", { buffer = buf, nowait = true })
      vim.keymap.set("t", "<c-l>", "<c-l>", { buffer = buf, nowait = true })
    end

    vim.api.nvim_create_autocmd("BufEnter", {
      buffer = buf,
      callback = function()
        vim.cmd.startinsert()
      end,
    })
  end

  return terminals[termkey]
end

---@param cmd? string[]|string
---@param opts? LazyTermOpts
function M.toggle_terminal(cmd, opts)
  M.open_terminal(cmd, opts)
end

return M
