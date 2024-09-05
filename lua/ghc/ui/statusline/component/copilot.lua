local session = require("ghc.context.session")

local status_icon_map = {
  Inactive = eve.icons.cmp.copilot_error,
  InProgress = eve.icons.cmp.copilot,
  Normal = eve.icons.cmp.copilot,
  Warning = eve.icons.cmp.copilot_warn,
}

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "copilot",
  condition = function()
    return not not package.loaded["copilot"] and session.flight_copilot:snapshot()
  end,
  render = function()
    local status = require("copilot.api").status.data.status
    local icon = status_icon_map[status] or eve.icons.cmp.copilot ---@type string
    local text = icon .. " " ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    local hl_text = eve.nvimbar.txt(text, (status == nil or #status < 1) and "f_sl_text" or ("f_sl_copilot_" .. status))
    return hl_text, width
  end,
}

return M
