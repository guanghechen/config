local oxi = require("fml.std.oxi")
local icons = require("fml.ui.icons")

---@class fml.ui.signcolumn
local M = {}

---@class fml.ui.signcolumn.names
M.names = {
  select_input_cursor = oxi.uuid(),
}

---@class fml.ui.signcolumn.signs
M.signs = {
  select_input_cursor = vim.fn.sign_define(
    M.names.select_input_cursor,
    { text = icons.ui.Telescope, texthl = "f_us_input_prompt" }
  ),
}

return M
