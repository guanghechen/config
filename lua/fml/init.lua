---@class fml
local fml = {}

---@class fml.core
fml.core = {
  json = require("fml.core.json"),
  md5 = require("fml.core.md5"),
  os = require("fml.core.os"),
}

---@class fml.core
fml.fn = {
  calc_fileicon = require("fml.fn.calc_fileicon"),
}

return fml
