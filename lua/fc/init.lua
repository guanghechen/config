---@class fc.std
local std = {
  array = require("fc.std.array"),
  box = require("fc.std.box"),
  color = require("fc.std.color"),
  is = require("fc.std.is"),
  json = require("fc.std.json"),
  md5 = require("fc.std.md5"),
  os = require("fc.std.os"),
  reporter = require("fc.std.reporter"),
  string = require("fc.std.string"),
  tmux = require("fc.std.tmux"),
}

---@class fc : fc.std
---@field public std                    fc.std
local fml = vim.tbl_extend("force", std, {
  std = std,
})

return fml
