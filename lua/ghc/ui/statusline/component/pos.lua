---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "pos",
  will_change = function (context, prev_context)
    return prev_context == nil
  end,
  pieces = {
    {
      hlname = function()
        return "f_sl_text"
      end,
      text = function()
        return fml.ui.icons.ui.Location .. " %l·%c"
      end,
    },
  },
}

return M
