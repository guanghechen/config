---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "copilot",
  condition = function()
    return not not package.loaded["copilot"] and ghc.context.session.flight_copilot:snapshot()
  end,
  render = function()
    local status = require("copilot.api").status.data.status
    local text = fml.ui.icons.cmp.copilot .. " " ---@type string
    local hlname = (status == nil or #status < 1) and "f_sl_text" or ("f_sl_copilot_" .. status)
    local width = vim.fn.strwidth(text) ---@type integer
    return fml.nvimbar.txt(text, hlname), width
  end
}

return M
