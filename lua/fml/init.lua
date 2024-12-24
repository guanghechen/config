---@class fml.fn
local fn = {
  dressing_float_win = require("fml.fn.dressing_float_win"),
  select = require("fml.fn.select"),
  select_files = require("fml.fn.select_files"),
  statuscolumn = require("eve.fn.statuscolumn"),
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
---@field public fn                     fml.fn
---@field public ux                     fml.ux
local fml = {
  fn = fn,
  ux = ux,
}

return fml
