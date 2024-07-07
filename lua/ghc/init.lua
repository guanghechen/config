---@class ghc.context
local context = {
  client = require("ghc.context.client"),
  session = require("ghc.context.session"),
  transient = require("ghc.context.transient"),
}

---@class ghc.command
local command = {
  context = require("ghc.command.context"),
  copy = require("ghc.command.copy"),
  debug = require("ghc.command.debug"),
  replace = require("ghc.command.replace"),
  run = require("ghc.command.run"),
  toggle = require("ghc.command.toggle"),
}

---@class ghc.constant
local constant = {
  command = require("ghc.constant.command"),
}

---@class ghc.ui
local ui = {
  statusline = require("ghc.ui.statusline"),
  tabline = require("ghc.ui.tabline"),
  theme = require('ghc.ui.theme'),
}

---@class ghc
---@field public context      ghc.context
---@field public command      ghc.command
---@field public constant     ghc.constant
---@field public ui           ghc.ui
local ghc = {
  context = context,
  command = command,
  constant = constant,
  ui = ui,
}

return ghc
