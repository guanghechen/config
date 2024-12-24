---@class eve.builtin
local builtin = {
  G = require("eve.builtin.G"),
  debug = require("eve.builtin.debug"),
  lsp = require("eve.builtin.lsp"),
  mvc = require("eve.builtin.mvc"),
  nvim = require("eve.builtin.nvim"),
  qflist = require("eve.builtin.qflist"),
  widgets = require("eve.builtin.widgets"),
}

---@class eve.fn
local fn = {
  foldexpr = require("eve.fn.foldexpr"),
  get_clipboard = require("eve.fn.get_clipboard"),
  hmr = require("eve.fn.hmr"),
  refresh_state = require("eve.fn.refresh_state"),
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
