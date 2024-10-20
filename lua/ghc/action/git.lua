---@class ghc.action.git
local M = {}

---! Function to check clipboard with retries
---@param cwd                           string
---@return nil
local function get_filepath_from_lazygit(cwd)
  ---@diagnostic disable-next-line: unused-local
  for i = 1, 5 do
    local relative_filepath = vim.fn.getreg("+")
    if relative_filepath ~= "" then
      return eve.path.join(cwd, relative_filepath)
    end
    vim.uv.sleep(30)
  end
end

---@return string
local function get_lazygit_config_filepath()
  local HOME_LAZYGIT = eve.path.locate_app_config_home("lazygit") ---@type string

  ---@type string[]
  local candidate_config_filepaths = {
    eve.path.join(HOME_LAZYGIT, "/config.yaml"),
    eve.path.join(HOME_LAZYGIT, "/theme/local.yaml"),
  }

  local config_filepaths = {} ---@type string[]
  for _, config_filepath in ipairs(candidate_config_filepaths) do
    if vim.fn.filereadable(config_filepath) ~= 0 then
      table.insert(config_filepaths, config_filepath)
    end
  end
  return table.concat(config_filepaths, ",")
end

---https://github.com/kdheepak/lazygit.nvim/issues/22#issuecomment-1815426074
---@param cwd                           string
---@return nil
local function edit_lazygit_file_in_buffer(cwd)
  local bufnr = eve.locations.get_current_bufnr() ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    eve.reporter.error({
      from = "ghc.action.git",
      subject = "edit_lazygit_file_in_buffer",
      message = "No valid buf found.",
      details = { cwd = cwd, bufnr = bufnr },
    })
    return
  end

  local channel_id = vim.fn.getbufvar(bufnr, "terminal_job_id")
  if not channel_id then
    eve.reporter.error({
      from = "ghc.action.git",
      subject = "edit_lazygit_file_in_buffer",
      message = "No terminal job ID found.",
    })
    return
  end

  vim.fn.chansend(channel_id, "\15") -- \15 is <C-o>
  vim.cmd("close") -- Close Lazygit

  local relative_filepath = get_filepath_from_lazygit(cwd)
  if not relative_filepath then
    eve.reporter.error({
      from = "ghc.action.git",
      subject = "edit_lazygit_file_in_buffer",
      message = "Clipboard is empty or invalid.",
    })
    return
  end

  local winnr = eve.locations.get_current_winnr() ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    eve.reporter.error({
      from = "ghc.action.git",
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
  local config_path = get_lazygit_config_filepath()
  local bufnr = fml.api.term.toggle_or_create({
    name = name,
    command = "lazygit --use-config-file " .. vim.fn.fnameescape(config_path) .. " " .. table.concat(args or {}, " "),
    cwd = cwd,
    permanent = true,
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
  open_lazygit("lazygit_workspace", eve.path.workspace())
end

---@return nil
function M.toggle_lazygit_cwd()
  open_lazygit("lazygit_cwd", eve.path.cwd())
end

---@return nil
function M.toggle_lazygit_file_history()
  local filepath = vim.api.nvim_buf_get_name(0)
  open_lazygit("lazygit_file_history", eve.path.cwd(), { "-f", vim.fn.fnameescape(filepath) })
end

---@return nil
function M.open_diffview()
  local diffview = require("diffview") ---@type any
  diffview.open()
end

---@return nil
function M.open_diffview_filehistory()
  local diffview = require("diffview") ---@type any
  local filepath = eve.path.current_filepath()
  diffview.file_history(nil, filepath)
end

return M
