---@class ghc.action
local action = {
  diagnostic = require("ghc.action.diagnostic"),
  explorer = require("ghc.action.explorer"),
  lsp = require("ghc.action.lsp"),
  theme = require("ghc.action.theme"),
}

---@class ghc.ux
local ux = {
  statusline = require("ghc.ux.statusline"),
  tabline = require("ghc.ux.tabline"),
  winline = require("ghc.ux.winline"),
  theme = require("ghc.ux.theme"),
}

---@class ghc
---@field public action                 ghc.action
---@field public ux                     ghc.ux
local ghc = {
  action = action,
  ux = ux,
}

return ghc
