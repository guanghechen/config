---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "find_recent",
  render = function()
    local text = " " .. ghc.context.session.find_scope:snapshot() .. " "
    local width = vim.fn.strwidth(text)
    return fml.nvimbar.txt(text, "f_sl_flag_scope"), width
  end,
}

return M
