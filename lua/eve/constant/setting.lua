---@class eve.constant.setting
local M = {}

M.feedkeys = {
  UNDO = vim.api.nvim_replace_termcodes("<C-G>u", true, true, true),
}

---@class eve.constant.setting.ai_providers
M.ai_providers = {
  "copilot",
  "deepseek",
  "aoai",
}

---@class eve.constant.setting.themes
M.themes = {
  "catppuccin-frappe",
  "catppuccin-latte",
  "catppuccin-macchiato",
  "catppuccin-mocha",
  "gruvbox-dark",
  "gruvbox-light",
  "nord",
  "one-half-dark",
  "one-half-light",
}

---@class eve.constant.setting.togglers
M.togglers = {
  "ai_provider",
  "flight",
  "hipatterns_local",
  "markdown",
  "mardkown_local",
  "maximize",
  "relativenumber",
  "relativenumber_local",
  "theme",
  "theme_variant",
  "transparency",
  "username",
  "wrap_local",
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
  BUFID_MIDDLE = "eve_bufid_middle",
  FLAG_SOURCEFILE = "eve_is_sourcefile",
  WINLINE_DISABLED = "eve_winline_disabled",
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
