---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "copilot",
  condition = function()
    return not not package.loaded["copilot"] and ghc.context.session.flight_copilot:get_snapshot()
  end,
  pieces = {
    {
      hlname = function()
        local status = require("copilot.api").status.data.status
        return (status == nil or #status < 1) and "f_sl_text" or ("f_sl_copilot_" .. status)
      end,
      text = function()
        return fml.ui.icons.cmp.copilot .. " "
      end,
    },
  },
}

return M
