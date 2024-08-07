---@class fml.constant
local M = {}

---! special symbols.
M.EDITING_INPUT_PREFIX = "@#!fml!#@"

---! buftypes
M.BT_NOWRITE = "nowrite"
M.BT_NOFILE = "nofile"

---! filetypes
M.FT_NEOTREE = "neo-tree"
M.FT_SEARCH_INPUT = "search-input"
M.FT_SEARCH_MAIN = "search-main"
M.FT_SEARCH_PREVIEW = "search-preview"
M.FT_SEARCH_REPLACE = "search-replace"
M.FT_SELECT_INPUT = "select-input"
M.FT_SELECT_MAIN = "select-main"
M.FT_TERM = "term"

---! tab names
M.TN_SEARCH_REPLACE = "ghc_search_replace"

M.BUF_UNTITLED = "untitled"
M.SESSION_SAVE_OPTION = "buffers,curdir,folds,help,resize,tabpages,unix,winpos,winsize"
M.SESSION_AUTOSAVE_OPTION = "buffers,curdir,folds,help,resize,tabpages,unix,winpos,winsize"
M.TAB_UNNAMED = "unnamed"
M.TAB_HISTORY_CAPACITY = 100
M.WIN_HISTORY_CAPACITY = 100
M.WIN_BUF_HISTORY_CAPACITY = 100

return M
