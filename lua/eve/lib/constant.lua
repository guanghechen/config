---@class eve.lib.constant
local M = {}

---! Session settings

M.SESSION_SAVE_OPTION = "blank,buffers,curdir,folds,globals,help,resize,slash,skiprtp,tabpages,unix,winpos,winsize"
M.SESSION_AUTOSAVE_OPTION = "blank,buffers,curdir,folds,globals,help,resize,slash,skiprtp,tabpages,unix,winpos,winsize"

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

---! Buffer types

M.BT_NOWRITE = "nowrite"
M.BT_NOFILE = "nofile"
M.BT_QUICKFIX = "quickfix"

---! sign_ids

M.SIGN_NR_SEARCH_MAIN_CURRENT = 2333
M.SIGN_NR_SEARCH_MAIN_PRESENT = 2334

---! Special symbols.

M.EDITING_INPUT_PREFIX = "@#!eve!#@"

return M
