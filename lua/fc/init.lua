---@class fc.std
local std = {
  array = require("fc.std.array"),
  boolean = require("fc.std.boolean"),
  box = require("fc.std.box"),
  color = require("fc.std.color"),
  fs = require("fc.std.fs"),
  is = require("fc.std.is"),
  json = require("fc.std.json"),
  md5 = require("fc.std.md5"),
  navigate = require("fc.std.navigate"),
  object = require("fc.std.object"),
  os = require("fc.std.os"),
  reporter = require("fc.std.reporter"),
  scheduler = require("fc.std.scheduler"),
  string = require("fc.std.string"),
  tmux = require("fc.std.tmux"),
}

---@class fc : fc.std
---@field public std                    fc.std
local fc = vim.tbl_extend("force", std, {
  std = std,
})

return fc
