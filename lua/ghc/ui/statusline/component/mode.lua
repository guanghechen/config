---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "mode",
  will_change = function(context, prev_context)
    return prev_context == nil or context.mode ~= prev_context.mode
  end,
  condition = function()
    return vim.api.nvim_get_current_win() == vim.g.statusline_winid
  end,
  pieces = {
    {
      hlname = function(context)
        return "f_sl_text_" .. context.mode
      end,
      text = function(context)
        return " " .. context.mode_name
      end,
    },
  },
}

return M
