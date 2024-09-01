---@class fc.collection
local collection = {
  AdvanceHistory = require("fc.collection.history_advance"),
  BatchHandler = require("fc.collection.batch_handler"),
  BatchDisposable = require("fc.collection.batch_disposable"),
  CircularQueue = require("fc.collection.circular_queue"),
  Dirtier = require("fc.collection.dirtier"),
  Disposable = require("fc.collection.disposable"),
  Frecency = require("fc.collection.frecency"),
  History = require("fc.collection.history"),
  Observable = require("fc.collection.observable"),
  Subscriber = require("fc.collection.subscriber"),
  Subscribers = require("fc.collection.subscribers"),
  Ticker = require("fc.collection.ticker"),
  Viewmodel = require("fc.collection.viewmodel"),
}

---@class fc.std
local std = {
  array = require("fc.std.array"),
  boolean = require("fc.std.boolean"),
  box = require("fc.std.box"),
  color = require("fc.std.color"),
  debug = require("fc.std.debug"),
  fs = require("fc.std.fs"),
  highlight = require("fc.std.highlight"),
  is = require("fc.std.is"),
  json = require("fc.std.json"),
  md5 = require("fc.std.md5"),
  navigate = require("fc.std.navigate"),
  object = require("fc.std.object"),
  os = require("fc.std.os"),
  oxi = require("fc.std.oxi"),
  path = require("fc.std.path"),
  reporter = require("fc.std.reporter"),
  scheduler = require("fc.std.scheduler"),
  string = require("fc.std.string"),
  tmux = require("fc.std.tmux"),
  util = require("fc.std.util"),
}

---@class fc : fc.std
---@field public c                      fc.collection
---@field public collection             fc.collection
---@field public std                    fc.std
local fc = vim.tbl_extend("force", std, {
  c = collection,
  collection = collection,
  std = std,
})

return fc
