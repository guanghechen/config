---@class ghc.context
local context = {
  replace = require("ghc.context.replace"),
  shared = require("ghc.context.shared"),
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
  Textarea = require("ghc.ui.textarea"),
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
