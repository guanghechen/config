local __module_name__ = "fml.action.term" ---@type string

local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local editor = require("eve.module.editor")
local state = require("eve.state")

local toggle_term = require("fml.action.term.toggle").toggle

---@return string|nil
local function get_lazygit_config_filepath()
  local HOME_LAZYGIT = path.locate_app_config_home("lazygit") ---@type string

  ---@type string[]
  local candidate_config_filepaths = {
    path.join(HOME_LAZYGIT, "local/theme.yml"),
    path.join(HOME_LAZYGIT, "config.yml"),
  }

  for _, config_filepath in ipairs(candidate_config_filepaths) do
    if vim.fn.filereadable(config_filepath) ~= 0 then
      return config_filepath
    end
  end
  return nil
end

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
---@param cwd                           string
---@return nil
local function edit_lazygit_file_in_buffer(cwd)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = state.tab.get_winnr_sourcefile(tabnr) ---@type integer|nil
  local bufnr_sourcefile = state.tab.get_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    reporter.error({
      from = __module_name__,
      subject = "edit_lazygit_file_in_buffer",
      message = "No valid buf found.",
      details = { cwd = cwd, bufnr = bufnr_sourcefile },
    })
    return
  end

  local channel_id = vim.fn.getbufvar(bufnr_sourcefile, "terminal_job_id")
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

  editor.open_filepath(winnr_sourcefile, relative_filepath)
end

---@param name                          string
---@param cwd                           string
---@param args                          ?string[]
---@return nil
local function open_lazygit(name, cwd, args)
  local config_path = get_lazygit_config_filepath() ---@type string|nil
  local cmd = config_path and "lazygit -ucf " .. vim.fn.shellescape(config_path) .. " " .. table.concat(args or {}, " ")
    or "lazygit " .. table.concat(args or {}, " ")

  local terminal = toggle_term({
    name = name,
    cmd = cmd,
    cwd = cwd,
    permanent = false,
  })

  local bufnr = terminal:get_bufnr() ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) and terminal:status() == "visible" then
    local function edit()
      edit_lazygit_file_in_buffer(cwd)
    end
    vim.keymap.set("t", "<C-e>", edit, { buffer = bufnr, noremap = true, silent = true })
  end
end

---@class fml.action.term
local M = {}

---@return nil
function M.lazygit_cwd()
  local cwd = path.cwd() ---@type string
  open_lazygit("lazygit_cwd", cwd)
end

---@return nil
function M.lazygit_workspace()
  local cwd = path.workspace() ---@type string
  open_lazygit("lazygit_workspace", cwd)
end

---@return nil
function M.lazygit_file_history()
  local cwd = path.cwd() ---@type string
  local filepath = path.current_filepath() ---@type string
  local args = { "-f", vim.fn.shellescape(filepath) } ---@type string[]
  open_lazygit("lazygit_file_history", cwd, args)
end

return M
