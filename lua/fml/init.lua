---autocmd
require("fml.autocmd")

---@class fml.api
local api = {
  buf = require("fml.api.buf"),
  lsp = require("fml.api.lsp"),
  state = require("fml.api.state"),
  tab = require("fml.api.tab"),
  term = require("fml.api.term"),
  win = require("fml.api.win"),
}

---@class fml.fn
local fn = {
  foldexpr = require("fml.fn.foldexpr"),
  watch_observables = require("fml.fn.watch_observables"),
}

---@class fml.std
local std = {
  G = require("fml.std.G"),
  clipboard = require("fml.std.clipboard"),
  debug = require("fml.std.debug"),
  highlight = require("fml.std.highlight"),
  lsp = require("fml.std.lsp"),
  nvimbar = require("fml.std.nvimbar"),
  statuscolumn = require("fml.std.statuscolumn"),
  util = require("fml.std.util"),
}

---@class fml.ui
local ui = {
  FileSelect = require("fml.ui.file_select"),
  Input = require("fml.ui.input"),
  Nvimbar = require("fml.ui.nvimbar"),
  Setting = require("fml.ui.setting"),
  Select = require("fml.ui.select"),
  SimpleFileSelect = require("fml.ui.simple_file_select"),
  Textarea = require("fml.ui.textarea"),
  Theme = require("fml.ui.theme"),
  icons = require("fml.ui.icons"),
  signcolumn = require("fml.ui.signcolumn"),
  search = require("fml.ui.search"),
}

---@class fml : fml.global, fml.std
---@field public api                    fml.api
---@field public constant               fml.constant
---@field public fn                     fml.fn
---@field public std                    fml.std
---@field public ui                     fml.ui
local fml = vim.tbl_extend("force", std, require("fml.global"), {
  api = api,
  constant = require("fml.constant"),
  fn = fn,
  std = std,
  ui = ui,
})

return fml
