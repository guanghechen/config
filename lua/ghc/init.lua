---@class ghc.action
local action = {
  buf = require("ghc.action.buf"),
  tab = require("ghc.action.tab"),
  win = require("ghc.action.win"),
  lsp = require("ghc.action.lsp"),
  term = require("ghc.action.term"),

  ----

  copy = require("ghc.action.copy"),
  debug = require("ghc.action.debug"),
  diagnostic = require("ghc.action.diagnostic"),
  explorer = require("ghc.action.explorer"),
  find_bookmark_pinned = require("ghc.action.find_bookmark_pinned"),
  find_files = require("ghc.action.find_files"),
  find_git = require("ghc.action.find_git"),
  find_win_history = require("ghc.action.find_win_history"),
  git = require("ghc.action.git"),
  notification = require("ghc.action.notification"),
  refresh = require("ghc.action.refresh"),
  run = require("ghc.action.run"),
  scroll = require("ghc.action.scroll"),
  session = require("ghc.action.session"),
  search_files = require("ghc.action.search_files"),
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
