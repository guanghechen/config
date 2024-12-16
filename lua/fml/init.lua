---@class fml.api
local api = {
  term = require("fml.api.term"),
}

---@class fml.fn
local fn = {
  dressing_float_win = require("fml.fn.dressing_float_win"),
  foldexpr = require("fml.fn.foldexpr"),
  get_clipboard = require("fml.fn.get_clipboard"),
  refresh_state = require("fml.fn.refresh_state"),
  select = require("fml.fn.select"),
  select_files = require("fml.fn.select_files"),
  statuscolumn = require("fml.fn.statuscolumn"),
}

---@class fml.ux
local ux = {
  FileSelect = require("fml.ux.component.file_select"),
  Input = require("fml.ux.component.input"),
  Select = require("fml.ux.component.select"),
  Setting = require("fml.ux.component.setting"),
  SimpleFileSelect = require("fml.ux.component.simple_file_select"),
  Terminal = require("fml.ux.component.terminal"),
  Textarea = require("fml.ux.component.textarea"),
  search = require("fml.ux.component.search"),

  ---

  signcolumn = require("fml.ux.signcolumn"),
  theme = require("fml.ux.theme"),
}

---@class fml
---@field public api                    fml.api
---@field public fn                     fml.fn
---@field public ux                     fml.ux
local fml = {
  api = api,
  fn = fn,
  ux = ux,
}

return fml
