---@class ghc.action
local action = {
  buf = require("ghc.action.buf"),
  tab = require("ghc.action.tab"),
  win = require("ghc.action.win"),
  lsp = require("ghc.action.lsp"),

  ----

  diagnostic = require("ghc.action.diagnostic"),
  explorer = require("ghc.action.explorer"),
  find_win_history = require("ghc.action.find_win_history"),
  git = require("ghc.action.git"),
  notification = require("ghc.action.notification"),
  scroll = require("ghc.action.scroll"),
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
