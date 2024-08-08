require("ghc.autocmd")

---@class ghc.command
local command = {
  context = require("ghc.command.context"),
  copy = require("ghc.command.copy"),
  debug = require("ghc.command.debug"),
  find_files = require("ghc.command.find_files"),
  git = require("ghc.command.git"),
  refresh = require("ghc.command.refresh"),
  search_files = require("ghc.command.search_files"),
  run = require("ghc.command.run"),
  session = require("ghc.command.session"),
  scroll = require("ghc.command.scroll"),
  term = require("ghc.command.term"),
  toggle = require("ghc.command.toggle"),
}

---@class ghc.context
local context = {
  client = require("ghc.context.client"),
  session = require("ghc.context.session"),
  transient = require("ghc.context.transient"),
}

---@class ghc.state
local state = {
  frecency = require("ghc.state.frecency"),
  input_history = require("ghc.state.input_history"),
}

---@class ghc.ui
local ui = {
  statusline = require("ghc.ui.statusline"),
  tabline = require("ghc.ui.tabline"),
  winline = require("ghc.ui.winline"),
  theme = require("ghc.ui.theme"),
}

---@class ghc
---@field public command                ghc.command
---@field public context                ghc.context
---@field public state                  ghc.state
---@field public ui                     ghc.ui
local ghc = {
  command = command,
  context = context,
  state = state,
  ui = ui,
}

return ghc
