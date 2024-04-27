-- https://github.com/LazyVim/LazyVim/blob/f086bcde253c29be9a2b9c90b413a516f5d5a3b2/lua/lazyvim/util/terminal.lua#L1

---@class ghc.core.util.terminal.util
local util = {
  reporter = require("ghc.core.util.reporter"),
  table = require("ghc.core.util.table"),
}

---@class ghc.core.util.terminal
local M = {}

---@type table<string,LazyFloat>
local terminals = {}

---@param shell? string
function M.setup_terminal(shell)
  vim.o.shell = shell or vim.o.shell

  -- Special handling for pwsh
  if shell == "pwsh" or shell == "powershell" then
    -- Check if 'pwsh' is executable and set the shell accordingly
    if vim.fn.executable("pwsh") == 1 then
      vim.o.shell = "pwsh"
    elseif vim.fn.executable("powershell") == 1 then
      vim.o.shell = "powershell"
    else
      return util.reporter.error("No powershell executable found")
    end

    -- Setting shell command flags
    vim.o.shellcmdflag =
      "-NoLogo -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();$PSDefaultParameterValues['Out-File:Encoding']='utf8';"

    -- Setting shell redirection
    vim.o.shellredir = '2>&1 | %{ "$_" } | Out-File %s; exit $LastExitCode'

    -- Setting shell pipe
    vim.o.shellpipe = '2>&1 | %{ "$_" } | Tee-Object %s; exit $LastExitCode'

    -- Setting shell quote options
    vim.o.shellquote = ""
    vim.o.shellxquote = ""
  end
end

---@class LazyTermOpts: LazyCmdOptions
---@field interactive? boolean
---@field esc_esc? boolean
---@field ctrl_hjkl? boolean

-- Opens a floating terminal (interactive by default)
---@param cmd? string[]|string
---@param opts? LazyTermOpts
function M.open_terminal(cmd, opts)
  opts = vim.tbl_deep_extend("force", {
    ft = "term",
    size = { width = 0.9, height = 0.9 },
    backdrop = nil,
  }, opts or {}, { persistent = true }) --[[@as LazyTermOpts]]

  local termkey = vim.inspect({ cmd = cmd or "shell", cwd = opts.cwd, env = opts.env, count = vim.v.count1 })

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

---@param opts { id: string, cwd: string, cmd?: table }
function M.toggle_terminal(opts)
  local operations = util.table.merge_multiple_array({ "cd " .. '"' .. opts.cwd .. '"' }, opts.cmd or {})

  local id = opts.id
  local cmd = table.concat(operations, " && ")

  require("nvchad.term").toggle({
    id = id,
    cmd = cmd,
    pos = "float",
  })

  -- set term format
  local term = nil
  for _, item in pairs(vim.g.nvchad_terms) do
    if item.id == id then
      term = item
      break
    end
  end
  if term ~= nil then
    vim.bo[term.buf].filetype = "term"
  end
end

return M
