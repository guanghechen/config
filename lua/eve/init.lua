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
  Viewmodel = require("eve.collection.viewmodel"),
}

---@class eve.globals
local globals = {
  constants = require("eve.globals.constants"),
  icons = require("eve.globals.icons"),
  mvc = require("eve.globals.mvc"),
  widgets = require("eve.globals.widgets"),
}

---@type eve.oxi
local oxi = require("eve.oxi")

---@class eve.std
local std = {
  G = require("eve.std.G"),
  array = require("eve.std.array"),
  boolean = require("eve.std.boolean"),
  box = require("eve.std.box"),
  color = require("eve.std.color"),
  debug = require("eve.std.debug"),
  fs = require("eve.std.fs"),
  highlight = require("eve.std.highlight"),
  is = require("eve.std.is"),
  json = require("eve.std.json"),
  lsp = require("eve.std.lsp"),
  md5 = require("eve.std.md5"),
  navigate = require("eve.std.navigate"),
  nvimbar = require("eve.std.nvimbar"),
  object = require("eve.std.object"),
  os = require("eve.std.os"),
  path = require("eve.std.path"),
  reporter = require("eve.std.reporter"),
  scheduler = require("eve.std.scheduler"),
  string = require("eve.std.string"),
  tmux = require("eve.std.tmux"),
  util = require("eve.std.util"),
}

---@class eve : eve.globals, eve.std
---@field public c                      eve.collection
---@field public collection             eve.collection
---@field public globals                eve.globals
---@field public oxi                    eve.oxi
---@field public std                    eve.std
local eve = vim.tbl_extend("force", globals, std, {
  c = collection,
  collection = collection,
  globals = globals,
  oxi = oxi,
  std = std,
})

return eve
