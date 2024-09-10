---@class eve.constants
local M = {}

---! special symbols.
M.EDITING_INPUT_PREFIX = "@#!eve!#@"

---! buftypes
M.BT_NOWRITE = "nowrite"
M.BT_NOFILE = "nofile"
M.BT_QUICKFIX = "quickfix"

---! filetypes
M.FT_DIFFVIEW_FILES = "DiffviewFiles"
M.FT_NEOTREE = "neo-tree"
M.FT_SEARCH_INPUT = "search-input"
M.FT_SEARCH_MAIN = "search-main"
M.FT_SEARCH_PREVIEW = "search-preview"
M.FT_TERM = "term"

---! sign_ids
M.SIGN_NR_SEARCH_MAIN_CURRENT = 2333
M.SIGN_NR_SEARCH_MAIN_PRESENT = 2334

M.BUF_UNTITLED = "untitled"
M.SESSION_SAVE_OPTION = "buffers,curdir,folds,help,resize,tabpages,unix,winpos,winsize"
M.SESSION_AUTOSAVE_OPTION = "buffers,curdir,folds,help,resize,tabpages,unix,winpos,winsize"
M.TAB_UNNAMED = "unnamed"
M.TAB_HISTORY_CAPACITY = 99
M.WIN_HISTORY_CAPACITY = 99
M.WIN_BUF_HISTORY_CAPACITY = 99

M.LSP_CLIENT_NAME_ORDERS = {
  bashls = 5,
  clangd = 5,
  cssls = 5,
  dockerls = 5,
  docker_compose_language_service = 10,
  eslint = 7,
  html = 5,
  jsonls = 5,
  lua_ls = 5,
  pyright = 5,
  rust_analyzer = 5,
  tailwindcss = 7,
  taplo = 5,
  ts_ls = 5,
  vuels = 7,
  yamlls = 5,
}

return M
