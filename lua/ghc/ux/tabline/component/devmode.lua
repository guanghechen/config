local state = require("eve.state")

---@type fml.t.ux.nvimbar.IRawComponent
local M = {
  name = "cwd",
  condition = function()
    local devmode = state.state.flight.devmode:snapshot() ---@type boolean
    return devmode
  end,
  render = function()
    local text = "  devmode " ---@type string
    local hl_text = eve.nvim.txt(text, "f_tl_devmode") ---@type string
    local width = vim.api.nvim_strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
