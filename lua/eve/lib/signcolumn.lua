local icons = require("eve.constant.icon")

local oxi = require("eve.lib.oxi")

---@class eve.lib.signcolumn
local M = {}

---@class eve.lib.signcolumn.names
M.names = {
  search_input_cursor = oxi.uuid(),
  search_main_current = oxi.uuid(),
  search_main_present = oxi.uuid(),
  search_main_present_cur = oxi.uuid(),
  select_input_cursor = oxi.uuid(),
  select_main_current = oxi.uuid(),
}

-- stylua: ignore start
vim.fn.sign_define(M.names.search_input_cursor,     { text = icons.ui.Telescope,    texthl = "f_us_input_prompt" })
vim.fn.sign_define(M.names.search_main_current,     { text = icons.ui.ArrowPresent, texthl = "f_us_main_current" })
vim.fn.sign_define(M.names.search_main_present,     { text = icons.ui.ArrowPresent, texthl = "f_us_main_present" })
vim.fn.sign_define(M.names.search_main_present_cur, { text = icons.ui.ArrowPresent, texthl = "f_us_main_present_cur" })
vim.fn.sign_define(M.names.select_input_cursor,     { text = icons.ui.Telescope,    texthl = "f_us_input_prompt" })
vim.fn.sign_define(M.names.select_main_current,     { text = icons.ui.ArrowClosed,  texthl = "f_us_main_current" })
-- stylua: ignore end

return M
