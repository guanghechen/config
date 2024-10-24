---@class eve.collection
local collection = {
  AdvanceHistory = require("eve.collection.history_advance"),
  BatchHandler = require("eve.collection.batch_handler"),
  BatchDisposable = require("eve.collection.batch_disposable"),
  CircularQueue = require("eve.collection.circular_queue"),
  CircularStack = require("eve.collection.circular_stack"),
  Dirtier = require("eve.collection.dirtier"),
  Disposable = require("eve.collection.disposable"),
  Frecency = require("eve.collection.frecency"),
  History = require("eve.collection.history"),
  Observable = require("eve.collection.observable"),
  Subscriber = require("eve.collection.subscriber"),
  Subscribers = require("eve.collection.subscribers"),
  Ticker = require("eve.collection.ticker"),
}

---@type eve.context
local context = require("eve.context")

---@class eve.globals
local globals = {
  icons = require("eve.globals.icons"),
  locations = require("eve.globals.locations"),
  mvc = require("eve.globals.mvc"),
  qflist = require("eve.globals.qflist"),
  widgets = require("eve.globals.widgets"),
}

---@type eve.oxi
local oxi = require("eve.oxi")

---@class eve.std
local std = {
  G = require("eve.std.G"),
  array = require("eve.std.array"),
  async = require("eve.std.async"),
  boolean = require("eve.std.boolean"),
  box = require("eve.std.box"),
  buf = require("eve.std.buf"),
  color = require("eve.std.color"),
  constants = require("eve.std.constants"),
  debug = require("eve.std.debug"),
  equals = require("eve.std.equals"),
  fs = require("eve.std.fs"),
  json = require("eve.std.json"),
  lsp = require("eve.std.lsp"),
  md5 = require("eve.std.md5"),
  navigate = require("eve.std.navigate"),
  nvim = require("eve.std.nvim"),
  nvimbar = require("eve.std.nvimbar"),
  object = require("eve.std.object"),
  os = require("eve.std.os"),
  path = require("eve.std.path"),
  reporter = require("eve.std.reporter"),
  scheduler = require("eve.std.scheduler"),
  string = require("eve.std.string"),
  tab = require("eve.std.tab"),
  tmux = require("eve.std.tmux"),
  util = require("eve.std.util"),
  validator = require("eve.std.validator"),
  win = require("eve.std.win"),
}

---@class eve : eve.globals, eve.std
---@field public c                      eve.collection
---@field public collection             eve.collection
---@field public context                eve.context
---@field public globals                eve.globals
---@field public oxi                    eve.oxi
---@field public std                    eve.std
local eve = vim.tbl_extend("force", {}, globals, std, {
  c = collection,
  collection = collection,
  context = context,
  globals = globals,
  oxi = oxi,
  std = std,
})

return eve
