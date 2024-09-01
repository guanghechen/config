local icons = require("fml.ui.icons")

---@class fml.ui.signcolumn
local M = {}

---@class fml.ui.signcolumn.names
M.names = {
  search_input_cursor = fc.oxi.uuid(),
  search_main_current = fc.oxi.uuid(),
  search_main_present = fc.oxi.uuid(),
  search_main_present_cur = fc.oxi.uuid(),
  select_input_cursor = fc.oxi.uuid(),
  select_main_current = fc.oxi.uuid(),
}

vim.fn.sign_define(M.names.search_input_cursor, { text = icons.ui.Telescope, texthl = "f_us_input_prompt" })
vim.fn.sign_define(M.names.search_main_current, { text = icons.ui.ArrowPresent, texthl = "f_us_main_current" })
vim.fn.sign_define(M.names.search_main_present, { text = icons.ui.ArrowPresent, texthl = "f_us_main_present" })
vim.fn.sign_define(M.names.search_main_present_cur, { text = icons.ui.ArrowPresent, texthl = "f_us_main_present_cur" })
vim.fn.sign_define(M.names.select_input_cursor, { text = icons.ui.Telescope, texthl = "f_us_input_prompt" })
vim.fn.sign_define(M.names.select_main_current, { text = icons.ui.ArrowClosed, texthl = "f_us_main_current" })

return M
