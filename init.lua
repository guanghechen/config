if vim.g.vscode then
  require("integration.vscode")
  return
end

if vim.g.neovide then
  require("integration.neovide")
  return
end

require("integration.neovim")
