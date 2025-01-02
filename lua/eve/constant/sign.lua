local icons = require("eve.constant.icon")

---@class eve.constant.sign
local M = {}

M.NR_SEARCH_MAIN_CURRENT = 2333
M.NR_SEARCH_MAIN_PRESENT = 2334

M.SEARCH_INPUT_CURSOR = "SIGN_SEARCH_INPUT_CURSOR"
M.SEARCH_MAIN_CURRENT = "SIGN_SEARCH_MAIN_CURRENT"
M.SEARCH_MAIN_PRESENT = "SIGN_SEARCH_MAIN_PRESENT"
M.SEARCH_MAIN_PRESENT_CUR = "SIGN_SEARCH_MAIN_PRESENT_CUR"

M.SELECT_INPUT_CURSOR = "SIGN_SELECT_INPUT_CURSOR"
M.SELECT_MAIN_CURRENT = "SIGN_SELECT_MAIN_CURRENT"

-- stylua: ignore start
vim.fn.sign_define(M.SEARCH_INPUT_CURSOR,     { text = icons.ui.Telescope,    texthl = "f_us_input_prompt" })
vim.fn.sign_define(M.SEARCH_MAIN_CURRENT,     { text = icons.ui.ArrowPresent, texthl = "f_us_main_current" })
vim.fn.sign_define(M.SEARCH_MAIN_PRESENT,     { text = icons.ui.ArrowPresent, texthl = "f_us_main_present" })
vim.fn.sign_define(M.SEARCH_MAIN_PRESENT_CUR, { text = icons.ui.ArrowPresent, texthl = "f_us_main_present_cur" })

vim.fn.sign_define(M.SELECT_INPUT_CURSOR,     { text = icons.ui.Telescope,    texthl = "f_us_input_prompt" })
vim.fn.sign_define(M.SELECT_MAIN_CURRENT,     { text = icons.ui.ArrowClosed,  texthl = "f_us_main_current" })
-- stylua: ignore end

return M
