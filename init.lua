require("ark.bootstrap").setup()

if vim.g.vscode then
  require("ark.vendor.vscode")
  return
end

if vim.g.neovide then
  require("ark.vendor.neovide")
  return
end

if vim.g.yuivim then
  require("ark.vendor.yuivim")
  return
end

if vim.g.yozvim then
  require("ark.vendor.yozvim")
  return
end

require("ark.vendor.neovim")
