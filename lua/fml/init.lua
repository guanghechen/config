---@class fml.api
local api = {
  buffer = require("fml.api.buffer"),
  window = require("fml.api.window"),
}

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

---@class fml.fn
local fn = {
  calc_fileicon = require("fml.fn.calc_fileicon"),
  debounce_leading = require("fml.fn.debounce_leading"),
  debounce_tailing = require("fml.fn.debounce_tailing"),
  dispose_all = require("fml.fn.dispose_all"),
  get_selected_text = require("fml.fn.get_selected_text"),
  is_disposable = require("fml.fn.is_disposable"),
  is_observable = require("fml.fn.is_observable"),
  navigate_circular = require("fml.fn.navigate_circular"),
  navigate_limit = require("fml.fn.navigate_limit"),
  noop = require("fml.fn.noop"),
  watch_observables = require("fml.fn.watch_observables"),
}

---@class fml.std
local std = {
  clipboard = require("fml.std.clipboard"),
  color = require("fml.std.color"),
  debug = require("fml.std.debug"),
  fs = require("fml.std.fs"),
  json = require("fml.std.json"),
  md5 = require("fml.std.md5"),
  os = require("fml.std.os"),
  oxi = require("fml.std.oxi"),
  path = require("fml.std.path"),
  reporter = require("fml.std.reporter"),
  string = require("fml.std.string"),
  table = require("fml.std.table"),
  tmux = require("fml.std.tmux"),
}

---@class fml.ui
local ui = {
  Input = require("fml.ui.input"),
  Printer = require("fml.ui.printer"),
  Textarea = require("fml.ui.textarea"),
  Theme = require("fml.ui.theme"),
  icons = require("fml.ui.icons"),
}

---@class fml : fml.std
---@field public api          fml.api
---@field public collection   fml.collection
---@field public fn           fml.fn
---@field public std          fml.std
---@field public ui           fml.ui
local fml = vim.tbl_extend("force", std, {
  api = api,
  collection = collection,
  fn = fn,
  std = std,
  ui = ui,
})

return fml
