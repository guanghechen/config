local context_session = require("guanghechen.core.context.session")
local util_terminal = require("guanghechen.core.util.terminal")

-- Function to check clipboard with retries
local function get_filepath_from_lazygit()
  ---@diagnostic disable-next-line: unused-local
  for i = 1, 5 do
    local relative_filepath = vim.fn.getreg("+")
    if relative_filepath ~= "" then
      local workspace = fml.path.workspace()
      return fml.path.join(workspace, relative_filepath)
    end
    vim.uv.sleep(50)
  end
  return nil
end

---https://github.com/kdheepak/lazygit.nvim/issues/22#issuecomment-1815426074
local function edit_lazygit_file_in_buffer()
  local current_bufnr = vim.fn.bufnr("%")
  local channel_id = vim.fn.getbufvar(current_bufnr, "terminal_job_id")

  if not channel_id then
    fml.reporter.error({
      from = "git.lua",
      subject = "edit_lazygit_file_in_buffer",
      message = "No terminal job ID found.",
    })
    return
  end

  vim.fn.chansend(channel_id, "\15") -- \15 is <c-o>
  vim.cmd("close") -- Close Lazygit

  local relative_filepath = get_filepath_from_lazygit()
  if not relative_filepath then
    fml.reporter.error({
      from = "git.lua",
      subject = "edit_lazygit_file_in_buffer",
      message = "Clipboard is empty or invalid.",
    })
    return
  end

  local winid = context_session.caller_winnr:get_snapshot()

  if winid == nil then
    fml.reporter.error({
      from = "git.lua",
      subject = "edit_lazygit_file_in_buffer",
      message = "Could not find the original window.",
    })
    return
  end

  vim.fn.win_gotoid(winid)
  vim.cmd("e " .. relative_filepath)
end

---@param cmd string[]
---@param cwd string
local function open_lazygit(cmd, cwd)
  local float_term = util_terminal.open_terminal(cmd, {
    cwd = cwd,
    esc_esc = false,
    ctrl_hjkl = false,
    border = "none",
  })
  vim.keymap.set("t", "<c-e>", edit_lazygit_file_in_buffer, { buffer = float_term.buf, noremap = true, silent = true })
end

local function get_lazygit_config_filepath()
  local lazygit_config_dir = fml.path.locate_config_filepath("lazygit")
  local darken = ghc.context.theme.mode:get_snapshot() == "darken" ---@type boolean
  local config_filepaths = {
    fml.path.join(lazygit_config_dir, "config.yaml"),
    fml.path.join(
      lazygit_config_dir,
      darken and "theme.darken.yaml" or "theme.lighten.yaml"
    ),
  }
  local lazygit_theme_config_filepath = table.concat(config_filepaths, ",")
  return lazygit_theme_config_filepath
end

---@class guanghechen.action.git
local M = {}

function M.open_lazygit_workspace()
  local lazygit_theme_config_filepath = get_lazygit_config_filepath()
  local cmd = { "lazygit", "--use-config-file", lazygit_theme_config_filepath }
  local cwd = fml.path.workspace()
  open_lazygit(cmd, cwd)
end

function M.open_lazygit_cwd()
  local lazygit_theme_config_filepath = get_lazygit_config_filepath()
  local cmd = { "lazygit", "--use-config-file", lazygit_theme_config_filepath }
  local cwd = fml.path.cwd()
  open_lazygit(cmd, cwd)
end

function M.open_diffview()
  local diffview = require("diffview")
  diffview.open()
end

function M.open_diffview_filehistory()
  local diffview = require("diffview")
  local filepath = fml.path.current_filepath()
  diffview.file_history(nil, filepath)
end

function M.open_lazygit_file_history()
  local filepath = vim.api.nvim_buf_get_name(0)
  local cmd = { "lazygit", "-f", filepath }
  local cwd = fml.path.cwd()
  open_lazygit(cmd, cwd)
end

return M
