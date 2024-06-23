---@class fml
local fml = {}

---@class fml.core
fml.core = {
  json = require("fml.core.json"),
  md5 = require("fml.core.md5"),
  os = require("fml.core.os"),
  string = require("fml.core.string"),
  table = require("fml.core.table"),
}

---@class fml.fn
fml.fn = {
  calc_fileicon = require("fml.fn.calc_fileicon"),
  get_selected_text = require("fml.fn.get_selected_text"),
}

return fml
