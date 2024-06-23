---@class fml.collection
local collection = {
  BatchHandler = require("fml.collection.batch_handler"),
  BatchDisposable = require("fml.collection.batch_disposable"),
  CircularQueue = require("fml.collection.circular_queue"),
  Disposable = require("fml.collection.disposable"),
  History = require("fml.collection.history"),
  Observable = require("fml.collection.observable"),
  Subscriber = require("fml.collection.subscriber"),
  Subscribers = require("fml.collection.subscribers"),
  Viewmodel = require("fml.collection.viewmodel"),
}

---@class fml.core
local core = {
  json = require("fml.core.json"),
  md5 = require("fml.core.md5"),
  os = require("fml.core.os"),
  path = require("fml.core.path"),
  reporter = require("fml.core.reporter"),
  string = require("fml.core.string"),
  table = require("fml.core.table"),
  tmux = require("fml.core.tmux"),
}

---@class fml.fn
local fn = {
  calc_fileicon = require("fml.fn.calc_fileicon"),
  dispose_all = require("fml.fn.dispose_all"),
  get_selected_text = require("fml.fn.get_selected_text"),
  is_disposable = require("fml.fn.is_disposable"),
  is_observable = require("fml.fn.is_observable"),
  watch_observables = require("fml.fn.watch_observables"),
}

---@class fml : fml.core
---@field public collection   fml.collection
---@field public core         fml.core
---@field public fn           fml.fn
local fml = vim.tbl_extend("force", { collection = collection, core = core, fn = fn }, core)

return fml
