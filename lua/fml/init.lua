---@class fml.collection
local collection = {
  BatchHandler = require("fml.collection.batch_handler"),
  BatchDisposable = require("fml.collection.batch_disposable"),
  CircularQueue = require("fml.collection.circular_queue"),
  Disposable = require("fml.collection.disposable"),
  History = require("fml.collection.history"),
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
}

---@class fml.fn
local fn = {
  calc_fileicon = require("fml.fn.calc_fileicon"),
  dispose_all = require("fml.fn.dispose_all"),
  get_selected_text = require("fml.fn.get_selected_text"),
  is_disposable = require("fml.fn.is_disposable"),
}

---@class fml : fml.core
---@field public collection   fml.collection
---@field public core         fml.core
---@field public fn           fml.fn
local fml = vim.tbl_extend("force", { collection = collection, core = core, fn = fn }, core)

return fml
