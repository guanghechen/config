require("std.bootstrap").setup_patches()
require("std.bootstrap").setup_workspace()

_G.std = require("std")
_G.oxi = require("oxi")
_G.eve = require("eve")

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
