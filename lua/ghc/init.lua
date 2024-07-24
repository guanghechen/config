require("ghc.autocmd")

---@class ghc.command
local command = {
  context = require("ghc.command.context"),
  copy = require("ghc.command.copy"),
  debug = require("ghc.command.debug"),
  find = require("ghc.command.find"),
  git = require("ghc.command.git"),
  refresh = require("ghc.command.refresh"),
  replace = require("ghc.command.replace"),
  run = require("ghc.command.run"),
  session = require("ghc.command.session"),
  term = require("ghc.command.term"),
  toggle = require("ghc.command.toggle"),
}

---@class ghc.context
local context = {
  client = require("ghc.context.client"),
  session = require("ghc.context.session"),
  transient = require("ghc.context.transient"),
}

---@class ghc.ui
local ui = {
  statusline = require("ghc.ui.statusline"),
  tabline = require("ghc.ui.tabline"),
  winline = require("ghc.ui.winline"),
  theme = require("ghc.ui.theme"),
}

---@class ghc.util
local util = {
  find = {
    scope = require("ghc.util.find.scope"),
  },
}

---@class ghc
---@field public command                ghc.command
---@field public context                ghc.context
---@field public ui                     ghc.ui
---@field public util                   ghc.util
local ghc = {
  command = command,
  context = context,
  ui = ui,
  util = util,
}

return ghc
