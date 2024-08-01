local oxi = require("fml.std.oxi")
local icons = require("fml.ui.icons")

---@class fml.ui.signcolumn
local M = {}

---@class fml.ui.signcolumn.names
M.names = {
  search_input_cursor = oxi.uuid(),
  search_main_current = oxi.uuid(),
  select_input_cursor = oxi.uuid(),
  select_main_current = oxi.uuid(),
}

---@class fml.ui.signcolumn.signs
M.signs = {
  search_input_cursor = vim.fn.sign_define(
    M.names.search_input_cursor,
    { text = icons.ui.Telescope, texthl = "f_us_input_prompt" }
  ),
  search_main_current = vim.fn.sign_define(
    M.names.search_main_current,
    { text = icons.ui.ArrowClosed, texthl = "f_us_main_current" }
  ),
  select_input_cursor = vim.fn.sign_define(
    M.names.select_input_cursor,
    { text = icons.ui.Telescope, texthl = "f_us_input_prompt" }
  ),
  select_main_current = vim.fn.sign_define(
    M.names.select_main_current,
    { text = icons.ui.ArrowClosed, texthl = "f_us_main_current" }
  ),
}

return M
