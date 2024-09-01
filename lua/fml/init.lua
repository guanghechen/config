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
  get_clipboard = require("fml.fn.get_clipboard"),
  statuscolumn = require("fml.fn.statuscolumn"),
  watch_observables = require("fml.fn.watch_observables"),
}

---@type fml.util
local util = require("fml.util")

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

---@class fml : fml.global
---@field public api                    fml.api
---@field public constant               fml.constant
---@field public fn                     fml.fn
---@field public ui                     fml.ui
---@field public util                   fml.util
local fml = vim.tbl_extend("force", require("fml.global"), {
  api = api,
  constant = require("fml.constant"),
  fn = fn,
  ui = ui,
  util = util,
})

return fml
