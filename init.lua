require("bot").setup()

_G.ark = require("ark") ---@type ark
_G.dot = require("dot") ---@type dot
_G.era = require("era") ---@type era
_G.ux = require("ux") ---@type ux

if dot.path.is_git_repo() then
  local log_filepath = dot.path.locate_workspace_filepath("log.json")
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
