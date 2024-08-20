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
  BatchHandler = require("fml.collection.batch_handler"),
  BatchDisposable = require("fml.collection.batch_disposable"),
  CircularQueue = require("fml.collection.circular_queue"),
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
  array = require("fml.std.array"),
  boolean = require("fml.std.boolean"),
  box = require("fml.std.box"),
  clipboard = require("fml.std.clipboard"),
  color = require("fml.std.color"),
  debug = require("fml.std.debug"),
  highlight = require("fml.std.highlight"),
  fs = require("fml.std.fs"),
  is = require("fml.std.is"),
  json = require("fml.std.json"),
  lsp = require("fml.std.lsp"),
  md5 = require("fml.std.md5"),
  navigate = require("fml.std.navigate"),
  nvimbar = require("fml.std.nvimbar"),
  object = require("fml.std.object"),
  os = require("fml.std.os"),
  oxi = require("fml.std.oxi"),
  path = require("fml.std.path"),
  reporter = require("fml.std.reporter"),
  scheduler = require("fml.std.scheduler"),
  set = require("fml.std.set"),
  statuscolumn = require("fml.std.statuscolumn"),
  string = require("fml.std.string"),
  typ = require("fml.std.typ"),
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
  Textarea = require("fml.ui.textarea"),
  Theme = require("fml.ui.theme"),
  icons = require("fml.ui.icons"),
  signcolumn = require("fml.ui.signcolumn"),
  search = require("fml.ui.search"),
}

---@class fml : fml.std
---@field public api                    fml.api
---@field public constant               fml.constant
---@field public collection             fml.collection
---@field public disposable             fml.types.collection.IBatchDisposable
---@field public fn                     fml.fn
---@field public std                    fml.std
---@field public ui                     fml.ui
local fml = vim.tbl_extend("force", std, {
  api = api,
  constant = require("fml.constant"),
  collection = collection,
  disposable = require("fml.autocmd.disposable"),
  fn = fn,
  std = std,
  ui = ui,
})

return fml
