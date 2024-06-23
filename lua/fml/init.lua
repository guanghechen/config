---@class fml.collection
local collection = {
  CircularQueue = require("fml.collection.circular_queue"),
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
  get_selected_text = require("fml.fn.get_selected_text"),
}

---@class fml : fml.core
---@field public collection   fml.collection
---@field public core         fml.core
---@field public fn           fml.fn
local fml = vim.tbl_extend("force", { collection = collection, core = core, fn = fn }, core)

return fml
