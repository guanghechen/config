---@class fml.core
local core = {
  json = require("fml.core.json"),
  md5 = require("fml.core.md5"),
  os = require("fml.core.os"),
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
---@field public core     fml.core
---@field public fn       fml.fn
local fml = vim.tbl_extend("force", { fn = fn, core = core }, core)

return fml
