---@class fml.constant
local M = {}

---! buftypes
M.BT_REPLACE_PREVIEW = "nowrite"
M.BT_SEARCH_REPLACE = "nofile"

---! filetypes
M.FT_NEOTREE = "neo-tree"
M.FT_SEARCH_REPLACE = "search_replace"
M.FT_SELECT_INPUT = "select_input"
M.FT_SELECT_MAIN = "select_main"
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
