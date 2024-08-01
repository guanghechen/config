local client = require("ghc.context.client")

---@class ghc.command.git
local M = {}

---! Function to check clipboard with retries
---@param cwd                           string
---@return nil
local function get_filepath_from_lazygit(cwd)
  ---@diagnostic disable-next-line: unused-local
  for i = 1, 5 do
    local relative_filepath = vim.fn.getreg("+")
    if relative_filepath ~= "" then
      return fml.path.join(cwd, relative_filepath)
    end
    vim.uv.sleep(30)
  end
end

---@return string
local function get_lazygit_config_filepath()
  local lazygit_config_dir = fml.path.locate_config_filepath("lazygit")
  local darken = client.mode:snapshot() == "darken" ---@type boolean
  local config_filepaths = {
    fml.path.join(lazygit_config_dir, "config.yaml"),
    fml.path.join(lazygit_config_dir, darken and "theme.darken.yaml" or "theme.lighten.yaml"),
  }
  local lazygit_theme_config_filepath = table.concat(config_filepaths, ",")
  return lazygit_theme_config_filepath
end

---https://github.com/kdheepak/lazygit.nvim/issues/22#issuecomment-1815426074
---@param cwd                           string
---@return nil
local function edit_lazygit_file_in_buffer(cwd)
  local bufnr_cur = vim.fn.bufnr("%")
  local channel_id = vim.fn.getbufvar(bufnr_cur, "terminal_job_id")

  if not channel_id then
    fml.reporter.error({
      from = "guanghechen.command.git",
      subject = "edit_lazygit_file_in_buffer",
      message = "No terminal job ID found.",
    })
    return
  end

  vim.fn.chansend(channel_id, "\15") -- \15 is <C-o>
  vim.cmd("close") -- Close Lazygit

  local relative_filepath = get_filepath_from_lazygit(cwd)
  if not relative_filepath then
    fml.reporter.error({
      from = "guanghechen.command.git",
      subject = "edit_lazygit_file_in_buffer",
      message = "Clipboard is empty or invalid.",
    })
    return
  end

  local winnr = fml.api.state.win_history:present()
  if winnr == nil then
    fml.reporter.error({
      from = "guanghechen.command.git",
      subject = "edit_lazygit_file_in_buffer",
      message = "Could not find the original window.",
      details = { bufnr_cur = bufnr_cur, channel_id = channel_id },
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
  local config_path = get_lazygit_config_filepath()
  local bufnr = fml.api.term.toggle_or_create({
    name = name,
    position = "float",
    command = "lazygit --use-config-file " .. vim.fn.fnameescape(config_path) .. " " .. table.concat(args or {}, " "),
    cwd = cwd,
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

---@return nil
function M.toggle_lazygit_workspace()
  open_lazygit("lazygit_workspace", fml.path.workspace())
end

---@return nil
function M.toggle_lazygit_cwd()
  open_lazygit("lazygit_cwd", fml.path.cwd())
end

---@return nil
function M.toggle_lazygit_file_history()
  local filepath = vim.api.nvim_buf_get_name(0)
  open_lazygit("lazygit_file_history", fml.path.cwd(), { "-f", vim.fn.fnameescape(filepath) })
end

---@return nil
function M.open_diffview()
  local diffview = require("diffview")
  diffview.open()
end

---@return nil
function M.open_diffview_filehistory()
  local diffview = require("diffview")
  local filepath = fml.path.current_filepath()
  diffview.file_history(nil, filepath)
end

return M
