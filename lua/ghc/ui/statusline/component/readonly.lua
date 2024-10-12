---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "readonly",
  condition = function()
    local readonly = vim.api.nvim_get_option_value("readonly", { buf = 0 }) ---@type boolean
    return readonly
  end,
  render = function()
    local text = eve.icons.ui.Lock .. " [RO]" ---@type string
    local hl_text = eve.nvimbar.txt(text, "f_sl_readonly") ---@type string
    local width = vim.api.nvim_strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
