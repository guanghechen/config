---@class ghc.context
local context = {
  replace = require("ghc.context.replace"),
  shared = require("ghc.context.shared"),
  theme = require("ghc.context.theme"),
}

---@class ghc.command
local command = {
  replace = require("ghc.command.replace"),
}

---@class ghc.constant
local constant = {
  command = require("ghc.constant.command"),
}

---@class ghc.ui
local ui = {
  Input = require("ghc.ui.input"),
  Printer = require("ghc.ui.printer"),
  Textarea = require("ghc.ui.textarea"),
  Theme = require("ghc.ui.theme"),
  icons = require("ghc.ui.icons"),
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
