require("bootstrap").setup()

_G.ark = require("ark") ---@type ark
_G.dot = require("dot") ---@type dot
_G.std = require("std") ---@type std
_G.eve = require("eve") ---@type eve
_G.ux = require("ux") ---@type ux

if std.path.is_git_repo() then
  local log_filepath = std.path.locate_workspace_filepath("log.json")
  vim.env.NVIM_LOG_FILE = log_filepath
  vim.env.NVIM_LOG_LEVEL = vim.env.NVIM_LOG_LEVEL or "warn"
end

if vim.g.vscode then
  require("integration.vscode")
  return
end

if vim.g.neovide then
  require("integration.neovide")
  return
end

require("integration.neovim")
