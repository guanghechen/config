---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "noice",
  condition = function()
    return not not package.loaded["noice"]
  end,
  pieces = {
    {
      hlname = function()
        return "f_sl_noice_command"
      end,
      text = function()
        local status = require("noice").api.status
        return status.command.get() or ""
      end,
    },
    {
      hlname = function()
        return "f_sl_noice_mode"
      end,
      text = function()
        local status = require("noice").api.status
        return status.mode.get() or ""
      end,
    },
  },
}

return M
