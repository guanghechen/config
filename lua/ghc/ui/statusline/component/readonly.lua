---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "readonly",
  condition = function()
    local readonly = vim.api.nvim_get_option_value("readonly", { buf = 0 }) ---@type boolean
    return readonly
  end,
  render = function()
    local text = fml.ui.icons.ui.Lock .. " [RO]"
    local width = vim.fn.strwidth(text) ---@type integer
    return fml.nvimbar.txt(text, "f_sl_readonly"), width
  end
}

return M
