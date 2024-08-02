---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "pos",
  ---@diagnostic disable-next-line: unused-local
  will_change = function(context, prev_context)
    return prev_context == nil
  end,
  render = function()
    local text = fml.ui.icons.ui.Location .. " %l·%c" ---@type string
    local hl_text = fml.nvimbar.txt(text, "f_sl_text") ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
