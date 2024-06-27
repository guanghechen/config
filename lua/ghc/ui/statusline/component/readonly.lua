---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "readonly",
  condition = function ()
    local readonly = vim.api.nvim_get_option_value("readonly", { buf = 0 }) ---@type boolean
    return readonly
  end,
  pieces = {
    {
      hlname = function()
        return "f_sl_readonly"
      end,
      text = function()
        return fml.ui.icons.ui.Lock .. " [RO]"
      end,
    },
  },
}

return M
