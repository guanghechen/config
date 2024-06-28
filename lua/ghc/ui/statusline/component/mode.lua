---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "mode",
  will_change = function(context, prev_context)
    return prev_context == nil or context.mode ~= prev_context.mode
  end,
  condition = function()
    return vim.api.nvim_get_current_win() == vim.g.statusline_winid
  end,
  render = function(context)
    local text = " " .. context.mode_name ---@type string
    local hlname = "f_sl_text_" .. context.mode ---@type string
    return fml.nvimbar.add_highlight(text, hlname)
  end
}

return M
