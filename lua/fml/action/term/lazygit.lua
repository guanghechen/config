local __module_name__ = "fml.action.term" ---@type string

local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local editor = require("eve.module.editor")
local command = require("eve.command")

local toggle_term = require("fml.action.term.toggle").toggle

---! Function to check clipboard with retries
---@param cwd                           string
---@return nil
local function get_filepath_from_lazygit(cwd)
  ---@diagnostic disable-next-line: unused-local
  for i = 1, 5 do
    local relative_filepath = vim.fn.getreg("+")
    if relative_filepath ~= "" then
      return path.join(cwd, relative_filepath)
    end
    vim.uv.sleep(30)
  end
end

---https://github.com/kdheepak/lazygit.nvim/issues/22#issuecomment-1815426074
---@param context                       eve.command.IContext
---@param cwd                           string
---@return nil
local function edit_lazygit_file_in_buffer(context, cwd)
  local bufnr = context.bufnr ----@type integer
  if not editor.is_buf_valid(bufnr) then
    reporter.error({
      from = __module_name__,
      subject = "edit_lazygit_file_in_buffer",
      message = "No valid buf found.",
      details = { cwd = cwd, bufnr = bufnr },
    })
    return
  end

  local channel_id = vim.fn.getbufvar(bufnr, "terminal_job_id")
  if not channel_id then
    reporter.error({
      from = __module_name__,
      subject = "edit_lazygit_file_in_buffer",
      message = "No terminal job ID found.",
    })
    return
  end

  vim.fn.chansend(channel_id, "\15") -- \15 is <C-o>
  vim.cmd("close") -- Close Lazygit

  local relative_filepath = get_filepath_from_lazygit(cwd)
  if not relative_filepath then
    reporter.error({
      from = __module_name__,
      subject = "edit_lazygit_file_in_buffer",
      message = "Clipboard is empty or invalid.",
    })
    return
  end

  local winnr_source = command.context_winnr() ---@type integer|nil
  editor.open_filepath(winnr_source, relative_filepath)
end

---@param context                       eve.command.IContext
---@param name                          string
---@param cwd                           string
---@param args                          ?string[]
---@return nil
local function open_lazygit(context, name, cwd, args)
  local terminal = toggle_term({
    name = name,
    command = "lazygit " .. table.concat(args or {}, " "),
    cwd = cwd,
    permanent = false,
  })

  local bufnr = terminal:get_bufnr() ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) and terminal:status() == "visible" then
    local function edit()
      edit_lazygit_file_in_buffer(context, cwd)
    end
    vim.keymap.set("t", "<C-e>", edit, { buffer = bufnr, noremap = true, silent = true })
  end
end

---@class fml.action.term
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.lazygit_cwd(context)
  local cwd = path.cwd() ---@type string
  open_lazygit(context, "lazygit_cwd", cwd)
end

---@param context                       eve.command.IContext
---@return nil
function M.lazygit_workspace(context)
  local cwd = path.workspace() ---@type string
  open_lazygit(context, "lazygit_workspace", cwd)
end

---@param context                       eve.command.IContext
---@return nil
function M.lazygit_file_history(context)
  local cwd = path.cwd() ---@type string
  local filepath = path.current_filepath() ---@type string
  local args = { "-f", vim.fn.shellescape(filepath) } ---@type string[]
  open_lazygit(context, "lazygit_file_history", cwd, args)
end

return M
