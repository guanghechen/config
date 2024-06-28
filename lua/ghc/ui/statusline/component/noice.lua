---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "noice",
  condition = function()
    return not not package.loaded["noice"]
  end,
  render = function()
    local status = require("noice").api.status
    local text_noice_command = status.command.get() or ""
    local text_noice_mode = status.mode.get() or ""
    return fml.nvimbar.add_highlight(text_noice_command, "f_sl_noice_command")
        .. fml.nvimbar.add_highlight(text_noice_mode, "f_sl_noice_mode")
  end
}

return M
