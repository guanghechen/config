local path = require("eve.builtin.path")

---@class eve.constant.setting
local M = {}

M.feedkeys = {
  UNDO = vim.api.nvim_replace_termcodes("<C-G>u", true, true, true),
}

---@class eve.constant.setting.ai_providers
M.ai_providers = {
  "copilot",
  "deepseek",
}

---@class eve.constant.setting.flights
M.flights = {
  "ai",
  "ai_provider",
  "autoload",
  "autosave",
  "devmode",
  "dressing_hipairs",
  "dressing_winsep_fixed",
  "dressing_winsep_float",
  "lsp_inlay_hints",
  "lsp_code_lens",
  "spellcheck",
  "treesitter_context",
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
  "ai_provider",
  "flight",
  "hipatterns_local",
  "markdown",
  "maximize",
  "relativenumber",
  "relativenumber_local",
  "theme",
  "theme_variant",
  "transparency",
  "username",
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

---@class eve.constant.setting.tabtypes
M.tabtypes = {
  ALL = "all",
  DIFFVIEW = "diffview",
  NORMAL = "normal",
}

---@class eve.constant.setting.vars
M.vars = {
  BUFID_MIDDLE = "bufid_middle",
  WINLINE_DISABLED = "fml_winline_disabled",
}

---! Tab settings

M.TAB_HISTORY_CAPACITY = 100

---! Window settings

M.WIN_HISTORY_CAPACITY = 99
M.WIN_BUF_HISTORY_CAPACITY = 99

---! Buffer settings

M.BUF_UNTITLED = "untitled"

---! Special symbols.

M.EDITING_INPUT_PREFIX = "@#!eve!#@"

return M
