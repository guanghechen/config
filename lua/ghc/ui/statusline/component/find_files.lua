---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "find_files",
  render = function()
    local text = " " .. ghc.context.session.find_scope:snapshot() .. " " ---@type string
    local hl_text = fml.nvimbar.txt(text, "f_sl_flag_scope") ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
