local __module_name__ = "ghc.action.term" ---@type string

local checks = require("eve.lib.checks")
local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local state = require("eve.state")
local toggle_term = require("ghc.action.term.toggle").toggle

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

---https://github.com/kdheepak/lazygit.nvim/issues/22#issuecomment-1815426074
---@param cwd                           string
---@return nil
local function edit_lazygit_file_in_buffer(cwd)
  local bufnr = state.tab.get_current_bufnr() ----@type integer
  if not checks.is_buf_valid(bufnr) then
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

  local winnr = state.tab.get_current_winnr() ---@type integer
  if winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    reporter.error({
      from = __module_name__,
      subject = "edit_lazygit_file_in_buffer",
      message = "Could not find the original window.",
      details = { bufnr_cur = bufnr, channel_id = channel_id },
    })
    return
  end

  vim.api.nvim_set_current_win(winnr)
  vim.cmd("e " .. relative_filepath)
end

---@param name                          string
---@param cwd                           string
---@param args                          ?string[]
local function open_lazygit(name, cwd, args)
  local config_path = get_lazygit_config_filepath() ---@type string|nil
  local bufnr = toggle_term({
    name = name,
    command = config_path
        and "lazygit -ucf " .. vim.fn.fnameescape(config_path) .. " " .. table.concat(args or {}, " ")
      or "lazygit " .. table.concat(args or {}, " "),
    cwd = cwd,
    permanent = false,
  })

  if bufnr ~= nil then
    local function edit()
      edit_lazygit_file_in_buffer(cwd)
    end

    vim.keymap.set("t", "<esc>", "<esc>", { buffer = bufnr, noremap = true, silent = true })
    vim.keymap.set("t", "<esc><esc>", "<esc><esc>", { buffer = bufnr, noremap = true, silent = true })
    vim.keymap.set("t", "<C-e>", edit, { buffer = bufnr, noremap = true, silent = true })
  end
end

---@class ghc.action.term
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
  local args = { "-f", vim.fn.fnameescape(filepath) } ---@type string[]
  open_lazygit("lazygit_file_history", cwd, args)
end

return M
