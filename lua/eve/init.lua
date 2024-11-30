---@class eve.builtin
local builtin = {
  G = require("eve.builtin.G"),
  buf = require("eve.builtin.buf"),
  checks = require("eve.builtin.checks"),
  commander = require("eve.builtin.commander"),
  constant = require("eve.builtin.constant"),
  debug = require("eve.builtin.debug"),
  filetype = require("eve.builtin.filetype"),
  icons = require("eve.builtin.icons"),
  locations = require("eve.builtin.locations"),
  lsp = require("eve.builtin.lsp"),
  mvc = require("eve.builtin.mvc"),
  nvim = require("eve.builtin.nvim"),
  qflist = require("eve.builtin.qflist"),
  tab = require("eve.builtin.tab"),
  util = require("eve.builtin.util"),
  widgets = require("eve.builtin.widgets"),
  win = require("eve.builtin.win"),
}

---@class eve.fn
local fn = {
  hmr = require("eve.fn.hmr"),
  navigate = require("eve.fn.navigate"),
  schedule = require("eve.fn.schedule"),
}

---@type eve.state
local state = require("eve.state")

---@class eve : eve.builtin
---@field public fn                     eve.fn
---@field public state                  eve.state
local eve = vim.tbl_extend("force", {}, builtin, {
  context = state,
  fn = fn,
  state = state,
})

return eve
