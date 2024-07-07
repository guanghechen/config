---@class fml.constant
local M = {}

M.BUF_UNTITLED = "untitled"
M.SESSION_SAVE_OPTION = table.concat({ "blank", "buffers", "curdir", "folds", "help", "resize", "tabpages", "winpos", "winsize" }, ",")
M.SESSION_AUTOSAVE_OPTION = table.concat({ "blank", "buffers", "curdir", "folds", "help", "resize", "tabpages", "unix", "winpos", "winsize" }, ",")
M.TAB_UNNAMED = "unnamed"
M.TAB_HISTORY_CAPACITY = 100
M.WIN_HISTORY_CAPACITY = 100
M.WIN_BUF_HISTORY_CAPACITY = 100

return M
