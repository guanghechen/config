---@class fml.api
local api = {
  buf = require("fml.api.buf"),
  tab = require("fml.api.tab"),
  term = require("fml.api.term"),
  win = require("fml.api.win"),

  ---

  find = require("fml.api.find"),
  search = require("fml.api.search"),
}

---@class fml.fn
local fn = {
  foldexpr = require("fml.fn.foldexpr"),
  get_clipboard = require("fml.fn.get_clipboard"),
  refresh_state = require("fml.fn.refresh_state"),
  select = require("fml.fn.select"),
  statuscolumn = require("fml.fn.statuscolumn"),
}

---@type fml.util
local util = require("fml.util")

---@class fml.ux
local ux = {
  FileSelect = require("fml.ux.component.file_select"),
  Input = require("fml.ux.component.input"),
  Nvimbar = require("fml.ux.component.nvimbar"),
  Select = require("fml.ux.component.select"),
  Setting = require("fml.ux.component.setting"),
  SimpleFileSelect = require("fml.ux.component.simple_file_select"),
  Terminal = require("fml.ux.component.terminal"),
  Textarea = require("fml.ux.component.textarea"),
  search = require("fml.ux.component.search"),

  ---

  Theme = require("fml.ux.theme"),
  signcolumn = require("fml.ux.signcolumn"),
}

---@class fml
---@field public api                    fml.api
---@field public fn                     fml.fn
---@field public util                   fml.util
---@field public ux                     fml.ux
local fml = {
  api = api,
  fn = fn,
  util = util,
  ux = ux,
}

return fml
