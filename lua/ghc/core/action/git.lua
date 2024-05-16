---@class ghc.action.git.util
local util = {
  path = require("ghc.core.util.path"),
  terminal = require("ghc.core.util.terminal"),
}

---@class ghc.action.git.context
local context = {
  global = require("ghc.core.context.global"),
  repo = require("ghc.core.context.repo"),
}

-- Function to check clipboard with retries
local function get_filepath_from_lazygit()
  ---@diagnostic disable-next-line: unused-local
  for i = 1, 5 do
    local relative_filepath = vim.fn.getreg("+")
    if relative_filepath ~= "" then
      local workspace = util.path.workspace()
      return util.path.join(workspace, relative_filepath)
    end
    vim.loop.sleep(50)
  end
  return nil
end

---https://github.com/kdheepak/lazygit.nvim/issues/22#issuecomment-1815426074
local function edit_lazygit_file_in_buffer()
  local current_bufnr = vim.fn.bufnr("%")
  local channel_id = vim.fn.getbufvar(current_bufnr, "terminal_job_id")

  if not channel_id then
    vim.notify("No terminal job ID found.", vim.log.levels.ERROR)
    return
  end

  vim.fn.chansend(channel_id, "\15") -- \15 is <c-o>
  vim.cmd("close") -- Close Lazygit

  local relative_filepath = get_filepath_from_lazygit()
  if not relative_filepath then
    vim.notify("Clipboard is empty or invalid.", vim.log.levels.ERROR)
    return
  end

  local winid = context.repo.caller_winnr:get_snapshot()

  if winid == nil then
    vim.notify("Could not find the original window.", vim.log.levels.ERROR)
    return
  end

  vim.fn.win_gotoid(winid)
  vim.cmd("e " .. relative_filepath)
end

---@param cmd string[]
---@param cwd string
local function open_lazygit(cmd, cwd)
  local float_term = util.terminal.open_terminal(cmd, {
    cwd = cwd,
    esc_esc = false,
    ctrl_hjkl = false,
    border = "none",
  })
  vim.keymap.set("t", "<c-e>", edit_lazygit_file_in_buffer, { buffer = float_term.buf, noremap = true, silent = true })
end

local function get_lazygit_config_filepath()
  local nvim_config_dir = vim.fn.stdpath("config")
  local lazygit_config_dir = util.path.join(nvim_config_dir, "config/lazygit")
  local config_filepaths = {
    util.path.join(lazygit_config_dir, "config.yaml"),
    util.path.join(lazygit_config_dir, context.global.darken:get_snapshot() and "theme.darken.yaml" or "theme.lighten.yaml"),
  }
  local lazygit_theme_config_filepath = table.concat(config_filepaths, ",")
  return lazygit_theme_config_filepath
end

---@class ghc.action.git
local M = {}

function M.open_lazygit_workspace()
  local lazygit_theme_config_filepath = get_lazygit_config_filepath()
  local cmd = { "lazygit", "--use-config-file", lazygit_theme_config_filepath }
  local cwd = util.path.workspace()
  open_lazygit(cmd, cwd)
end

function M.open_lazygit_cwd()
  local lazygit_theme_config_filepath = get_lazygit_config_filepath()
  local cmd = { "lazygit", "--use-config-file", lazygit_theme_config_filepath }
  vim.notify("cmd:" .. vim.inspect(cmd))
  local cwd = util.path.cwd()
  open_lazygit(cmd, cwd)
end

function M.open_lazygit_file_history()
  local filepath = vim.api.nvim_buf_get_name(0)
  local cmd = { "lazygit", "-f", filepath }
  local cwd = util.path.cwd()
  open_lazygit(cmd, cwd)
end

return M
