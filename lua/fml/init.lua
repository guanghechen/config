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

---@class fml.core
local core = {
  clipboard = require("fml.core.clipboard"),
  json = require("fml.core.json"),
  md5 = require("fml.core.md5"),
  os = require("fml.core.os"),
  oxi = require("fml.core.oxi"),
  path = require("fml.core.path"),
  reporter = require("fml.core.reporter"),
  string = require("fml.core.string"),
  table = require("fml.core.table"),
  tmux = require("fml.core.tmux"),
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
  watch_observables = require("fml.fn.watch_observables"),
}

---@class fml.ui
local ui = {
  Input = require("fml.ui.input"),
  Printer = require("fml.ui.printer"),
  Textarea = require("fml.ui.textarea"),
  icons = require("fml.ui.icons"),
}

---@class fml : fml.core
---@field public api          fml.api
---@field public collection   fml.collection
---@field public core         fml.core
---@field public fn           fml.fn
---@field public ui           fml.ui
local fml = vim.tbl_extend("force", core, {
  api = api,
  collection = collection,
  core = core,
  fn = fn,
  ui = ui,
})

return fml
