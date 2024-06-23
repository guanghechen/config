---@class guanghechen
local M = {}

---@class guanghechen.clazz
M.clazz = {
  Timer = require("guanghechen.timer.Timer"),
}

---@class guanghechen.util
M.util = {
  buffer = require("guanghechen.util.buffer"),
  clipboard = require("guanghechen.util.clipboard"),
  debounce = require("guanghechen.util.debounce"),
  fs = require("guanghechen.util.fs"),
  navigator = require("guanghechen.util.navigator"),
  tmux = require("guanghechen.util.tmux"),
  window = require("guanghechen.util.window"),
}

return M
