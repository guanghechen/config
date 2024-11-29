local os_name = vim.uv.os_uname().sysname ---@type string|nil

---@class eve.builtin.constant
local M = {}

---! OS settings

M.IS_NIX = os_name == "Linux" ---@type boolean
M.IS_MAC = os_name == "Darwin" ---@type boolean
M.IS_WIN = os_name == "Windows_NT" ---@type boolean
M.IS_WSL = vim.fn.has("wsl") == 1 ---@type boolean
M.PATH_SEP = M.IS_WIN and "\\" or "/" ---@type string

---! Path settings

M.HOME_NVIM_CONFIG = vim.fn.stdpath("config") --[[@as string]]
M.HOME_NVIM_DATA = vim.fn.stdpath("data") --[[@as string]]
M.HOME_NVIM_STATE = vim.fn.stdpath("state") --[[@as string]]
M.HOME_CONTEXT = M.HOME_NVIM_STATE .. M.PATH_SEP .. "guanghechen" ---@type string

---! Session settings

M.SESSION_SAVE_OPTION = "buffers,curdir,folds,help,resize,tabpages,unix,winpos,winsize"
M.SESSION_AUTOSAVE_OPTION = "buffers,curdir,folds,help,resize,tabpages,unix,winpos,winsize"

---! Tab settings

M.TAB_UNNAMED = "unnamed"
M.TAB_HISTORY_CAPACITY = 100

---! Window settings

M.WIN_HISTORY_CAPACITY = 99
M.WIN_BUF_HISTORY_CAPACITY = 99

---! Buffer settings

M.BUF_UNTITLED = "untitled"

---! Variable names

M.V_WINLINE_DISABLED = "ghc_winline_disabled"

---! Buffer types

M.BT_NOWRITE = "nowrite"
M.BT_NOFILE = "nofile"
M.BT_QUICKFIX = "quickfix"

---! File types

M.FT_AERIAL = "aerial"
M.FT_BIGFILE = "bigfile"
M.FT_COPILOT_CHAT = "copilot-chat"
M.FT_CMP_MENU = "cmp_menu"
M.FT_CHECKHEALTH = "checkhealth"
M.FT_DIFFVIEW_FILES = "DiffviewFiles"
M.FT_FLASH_PROMPT = "flash_prompt"
M.FT_GITCOMMIT = "gitcommit"
M.FT_HELP = "help"
M.FT_LAZY = "lazy"
M.FT_MAN = "man"
M.FT_MASON = "mason"
M.FT_NEOTREE = "neo-tree"
M.FT_NEOTREE_POPUP = "neo-tree-popup"
M.FT_NOICE = "noice"
M.FT_NOTIFY = "notify"
M.FT_LSPINFO = "lspinfo"
M.FT_PLENARY_TEST_POPUP = "PlenaryTestPopup"
M.FT_QUICKFIX = "qf"
M.FT_SEARCH_INPUT = "search-input"
M.FT_SEARCH_MAIN = "search-main"
M.FT_SEARCH_PREVIEW = "search-preview"
M.FT_STARTUPTIME = "startuptime"
M.FT_TERM = "term"
M.FT_TROUBLE = "Trouble"
M.FT_WINSEP = "winsep"

---! sign_ids

M.SIGN_NR_SEARCH_MAIN_CURRENT = 2333
M.SIGN_NR_SEARCH_MAIN_PRESENT = 2334

---! Special symbols.

M.EDITING_INPUT_PREFIX = "@#!eve!#@"

return M
