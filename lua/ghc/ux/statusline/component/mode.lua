---@type fml.t.ux.nvimbar.IRawComponent
local M = {
  name = "mode",
  tight = true,
  will_change = function(context, prev_context)
    return prev_context == nil or context.mode ~= prev_context.mode
  end,
  render = function(context)
    local text = "  " .. context.mode_name .. " " ---@type string
    local hl_text = eve.nvim.txt(text, "f_sl_text_" .. context.mode) ---@type string
    local width = vim.api.nvim_strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
