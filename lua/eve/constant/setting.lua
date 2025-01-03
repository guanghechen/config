local path = require("eve.builtin.path")

---@class eve.constant.setting
local M = {}

---@class eve.constant.setting.flights
M.flights = {
  "autoload",
  "autosave",
  "copilot",
  "devmode",
  "dressing_hipairs",
  "dressing_winsep_fixed",
  "dressing_winsep_float",
  "lsp_inlay_hints",
  "lsp_code_lens",
  "spellcheck",
}

---@class eve.constant.setting.themes
M.themes = {
  "catppuccin-latte",
  "catppuccin-mocha",
  "gruvbox_dark",
  "gruvbox_light",
  "nord",
  "one_half_dark",
  "one_half_light",
}

---@class eve.constant.setting.togglers
M.togglers = {
  "flight",
  "relativenumber",
  "relativenumber_local",
  "theme",
  "theme_variant",
  "transparency",
  "wrap_local",
}

---@class eve.constant.setting.paths
M.paths = {
  theme = path.locate_context_filepath("theme"),
}

---@class eve.constant.setting.sessions
M.sessions = {
  persistent_options = table.concat({
    "blank",
    "buffers",
    "curdir",
    "folds",
    "globals",
    "help",
    "resize",
    "slash",
    "skiprtp",
    "tabpages",
    "unix",
    "winpos",
    "winsize",
  }, ","),
}

---! Tab settings

M.TAB_HISTORY_CAPACITY = 100

M.TT_ALL = "all"
M.TT_DIFFVIEW = "diffview"
M.TT_NORMAL = "normal"

---! Window settings

M.WIN_HISTORY_CAPACITY = 99
M.WIN_BUF_HISTORY_CAPACITY = 99

---! Buffer settings

M.BUF_UNTITLED = "untitled"

---! Variable names

M.V_WINLINE_DISABLED = "fml_winline_disabled"

---! Special symbols.

M.EDITING_INPUT_PREFIX = "@#!eve!#@"

return M
