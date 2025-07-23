require("std.bootstrap").setup_patches()
require("std.bootstrap").setup_workspace()

_G.std = require("std")
_G.oxi = require("oxi")
_G.eve = require("eve")

if vim.g.vscode then
  require("integration.vscode")
  return
end

if vim.g.neovide then
  require("integration.neovide")
  return
end

require("integration.neovim")
