-- Behavior reference: mini.surround commit 8d5d0c5aa92449368ac251e85451d79d8f69d296.

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.surrounds" ---@type string

local Action = require("era.keystroke.surrounds.action")
local Keymap = require("era.keystroke.surrounds.keymap")

---@class era.keystroke.surrounds
local M = {}

M.add = Action.add
M.delete = Action.delete
M.find = Action.find
M.highlight = Action.highlight
M.replace = Action.replace

M.setup = Keymap.setup

return M
