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

---@class ghc
---@field public context      ghc.context
---@field public command      ghc.command
---@field public constant     ghc.constant
local ghc = {
  context = context,
  command = command,
  constant = constant,
}

return ghc
