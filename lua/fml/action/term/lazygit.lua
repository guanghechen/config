local toggle_term = require("fml.action.term.toggle").toggle

local HOME_LAZYGIT = std.path.locate_app_config_home("lazygit") ---@type string
local lazygit_config_theme_filepath = std.path.join(HOME_LAZYGIT, "local/theme.yml") ---@type string
local lazygit_config_filepath = std.path.join(HOME_LAZYGIT, "config.yml") ---@type string

local ucf_filepath = vim.fn.shellescape(lazygit_config_filepath) ---@type string
local ucf_filepath_with_theme = table.concat({
  vim.fn.shellescape(lazygit_config_filepath),
  vim.fn.shellescape(lazygit_config_theme_filepath),
}, ",")

---@param name                          string
---@param cwd                           string
---@param args                          ?string[]
---@return nil
local function open_lazygit(name, cwd, args)
  local cf = std.path.is_exist_filepath(lazygit_config_theme_filepath) and ucf_filepath_with_theme or ucf_filepath ---@type string
  local argv = table.concat(args or {}, " ") ---@type string
  local cmd = #argv > 0 and string.format("lazygit --use-config-file=%s %s", cf, argv)
    or string.format("lazygit --use-config-file=%s", cf)
  toggle_term({
    name = name,
    cmd = cmd,
    cwd = cwd,
    permanent = true,
  })
end

---@class fml.action.term
local M = {}

---@return nil
function M.lazygit_cwd()
  local cwd = std.path.cwd() ---@type string
  open_lazygit("lazygit_cwd", cwd)
end

---@return nil
function M.lazygit_workspace()
  local cwd = std.path.workspace() ---@type string
  open_lazygit("lazygit_workspace", cwd)
end

---@return nil
function M.lazygit_file_history()
  local cwd = std.path.cwd() ---@type string
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local args = { "-f", vim.fn.shellescape(filepath) } ---@type string[]
  open_lazygit("lazygit_file_history", cwd, args)
end

return M
