local session = require("ghc.context.session")

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "copilot",
  condition = function()
    return not not package.loaded["copilot"] and session.flight_copilot:snapshot()
  end,
  render = function()
    local status = require("copilot.api").status.data.status
    local text = fml.ui.icons.cmp.copilot .. " " ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    local hl_text = eve.nvimbar.txt(text, (status == nil or #status < 1) and "f_sl_text" or ("f_sl_copilot_" .. status))
    return hl_text, width
  end,
}

return M
