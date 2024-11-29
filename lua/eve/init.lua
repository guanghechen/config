---@type eve.context
local context = require("eve.context")

---@class eve.builtin
local builtin = {
  constant = require("eve.builtin.constant"),
  json = require("eve.builtin.json"),
  md5 = require("eve.builtin.md5"),
  reporter = require("eve.builtin.reporter"),
}

---@class eve.fn
local fn = {
  hmr = require("eve.fn.hmr"),
  schedule = require("eve.fn.schedule"),
}

---@class eve.globals
local globals = {
  icons = require("eve.globals.icons"),
  locations = require("eve.globals.locations"),
  mvc = require("eve.globals.mvc"),
  qflist = require("eve.globals.qflist"),
  widgets = require("eve.globals.widgets"),
}

---@type eve.oxi
local oxi = require("eve.oxi")

---@class eve.std
local std = {
  G = require("eve.std.G"),
  array = require("eve.std.array"),
  async = require("eve.std.async"),
  box = require("eve.std.box"),
  buf = require("eve.std.buf"),
  color = require("eve.std.color"),
  commander = require("eve.std.commander"),
  constants = require("eve.std.constants"),
  debug = require("eve.std.debug"),
  filetype = require("eve.std.filetype"),
  fs = require("eve.std.fs"),
  lsp = require("eve.std.lsp"),
  navigate = require("eve.std.navigate"),
  nvim = require("eve.std.nvim"),
  nvimbar = require("eve.std.nvimbar"),
  path = require("eve.std.path"),
  string = require("eve.std.string"),
  tab = require("eve.std.tab"),
  time = require("eve.std.time"),
  tmux = require("eve.std.tmux"),
  util = require("eve.std.util"),
  validator = require("eve.std.validator"),
  win = require("eve.std.win"),
}

---@class eve : eve.builtin, eve.globals, eve.std
---@field public context                eve.context
---@field public fn                     eve.fn
---@field public globals                eve.globals
---@field public oxi                    eve.oxi
---@field public std                    eve.std
local eve = vim.tbl_extend("force", {}, builtin, globals, std, {
  context = context,
  fn = fn,
  globals = globals,
  oxi = oxi,
  std = std,
})

return eve
