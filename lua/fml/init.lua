---autocmd
require("fml.autocmd")

---@class fml.api
local api = {
  buf = require("fml.api.buf"),
  lsp = require("fml.api.lsp"),
  state = require("fml.api.state"),
  tab = require("fml.api.tab"),
  term = require("fml.api.term"),
  win = require("fml.api.win"),
}

---@class fml.collection
local collection = {
  AdvanceHistory = require("fml.collection.history_advance"),
  BatchHandler = require("fml.collection.batch_handler"),
  BatchDisposable = require("fml.collection.batch_disposable"),
  CircularQueue = require("fml.collection.circular_queue"),
  Dirtier = require("fml.collection.dirtier"),
  Disposable = require("fml.collection.disposable"),
  Frecency = require("fml.collection.frecency"),
  History = require("fml.collection.history"),
  Observable = require("fml.collection.observable"),
  Subscriber = require("fml.collection.subscriber"),
  Subscribers = require("fml.collection.subscribers"),
  Ticker = require("fml.collection.ticker"),
  Viewmodel = require("fml.collection.viewmodel"),
}

---@class fml.fn
local fn = {
  foldexpr = require("fml.fn.foldexpr"),
  watch_observables = require("fml.fn.watch_observables"),
}

---@class fml.std
local std = {
  G = require("fml.std.G"),
  boolean = require("fml.std.boolean"),
  box = require("fml.std.box"),
  clipboard = require("fml.std.clipboard"),
  color = require("fml.std.color"),
  debug = require("fml.std.debug"),
  highlight = require("fml.std.highlight"),
  fs = require("fml.std.fs"),
  lsp = require("fml.std.lsp"),
  navigate = require("fml.std.navigate"),
  nvimbar = require("fml.std.nvimbar"),
  object = require("fml.std.object"),
  oxi = require("fml.std.oxi"),
  path = require("fml.std.path"),
  reporter = require("fml.std.reporter"),
  scheduler = require("fml.std.scheduler"),
  set = require("fml.std.set"),
  statuscolumn = require("fml.std.statuscolumn"),
  tmux = require("fml.std.tmux"),
  util = require("fml.std.util"),
}

---@class fml.ui
local ui = {
  FileSelect = require("fml.ui.file_select"),
  Input = require("fml.ui.input"),
  Nvimbar = require("fml.ui.nvimbar"),
  Setting = require("fml.ui.setting"),
  Select = require("fml.ui.select"),
  SimpleFileSelect = require("fml.ui.simple_file_select"),
  Textarea = require("fml.ui.textarea"),
  Theme = require("fml.ui.theme"),
  icons = require("fml.ui.icons"),
  signcolumn = require("fml.ui.signcolumn"),
  search = require("fml.ui.search"),
}

---@class fml : fml.global, fml.std
---@field public api                    fml.api
---@field public constant               fml.constant
---@field public collection             fml.collection
---@field public fn                     fml.fn
---@field public std                    fml.std
---@field public ui                     fml.ui
local fml = vim.tbl_extend("force", std, require("fml.global"), {
  api = api,
  constant = require("fml.constant"),
  collection = collection,
  fn = fn,
  std = std,
  ui = ui,
})

return fml
