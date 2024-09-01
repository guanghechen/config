---@class fc.std
local std = {
  is = require("fc.std.is"),
  json = require("fc.std.json"),
  md5 = require("fc.std.md5"),
  os = require("fc.std.os"),
}

---@class fc : fc.std
---@field public std                    fc.std
local fml = vim.tbl_extend("force", std, {
  std = std,
})

return fml
