require("ark.bootstrap").setup()

if dot.path.is_git_repo() then
  local log_filepath = dot.path.locate_workspace_filepath("log.json")
  vim.env.NVIM_LOG_FILE = log_filepath
  vim.env.NVIM_LOG_LEVEL = vim.env.NVIM_LOG_LEVEL or "warn"
end

if vim.g.vscode then
  require("ark.vendor.vscode")
  return
end

if vim.g.neovide then
  require("ark.vendor.neovide")
  return
end

if vim.g.yozvim then
  require("ark.vendor.yozvim")
  return
end

require("ark.vendor.neovim")
