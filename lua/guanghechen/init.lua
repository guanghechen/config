---@class guanghechen
local M = {}

---@class guanghechen.clazz
M.clazz = {
  BatchDisposable = require("guanghechen.disposable.BatchDisposable"),
  Disposable = require("guanghechen.disposable.Disposable"),
  Observable = require("guanghechen.observable.Observable"),
  SafeBatchHandler = require("guanghechen.disposable.SafeBatchHandler"),
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
  disposable = require("guanghechen.util.disposable"),
  fs = require("guanghechen.util.fs"),
  misc = require("guanghechen.util.misc"),
  navigator = require("guanghechen.util.navigator"),
  observable = require("guanghechen.util.observable"),
  tmux = require("guanghechen.util.tmux"),
  window = require("guanghechen.util.window"),
}

return M
