---@class guanghechen
local M = {}

---@class guanghechen.clazz
M.clazz = {
  Observable = require("guanghechen.observable.Observable"),
  Subscriber = require("guanghechen.subscriber.Subscriber"),
  Subscribers = require("guanghechen.subscriber.Subscribers"),
  Timer = require("guanghechen.timer.Timer"),
  Viewmodel = require("guanghechen.viewmodel.Viewmodel"),
}

---@class guanghechen.util
M.util = {
  buffer = require("guanghechen.util.buffer"),
  clipboard = require("guanghechen.util.clipboard"),
  debounce = require("guanghechen.util.debounce"),
  fs = require("guanghechen.util.fs"),
  misc = require("guanghechen.util.misc"),
  navigator = require("guanghechen.util.navigator"),
  observable = require("guanghechen.util.observable"),
  tmux = require("guanghechen.util.tmux"),
  window = require("guanghechen.util.window"),
}

return M
