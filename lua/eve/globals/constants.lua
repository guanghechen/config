---@class eve.constants
local M = {}

---! special symbols.
M.EDITING_INPUT_PREFIX = "@#!eve!#@"

---! buftypes
M.BT_NOWRITE = "nowrite"
M.BT_NOFILE = "nofile"
M.BT_QUICKFIX = "quickfix"

---! filetypes
M.FT_CHECKHEALTH = "checkhealth"
M.FT_DIFFVIEW_FILES = "DiffviewFiles"
M.FT_NEOTREE = "neo-tree"
M.FT_NOTIFY = "notify"
M.FT_LSPINFO = "lspinfo"
M.FT_PLENARY_TEST_POPUP = "PlenaryTestPopup"
M.FT_SEARCH_INPUT = "search-input"
M.FT_SEARCH_MAIN = "search-main"
M.FT_SEARCH_PREVIEW = "search-preview"
M.FT_STARTUPTIME = "startuptime"
M.FT_TERM = "term"
M.FT_TROUBLE = "Trouble"

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

return M
