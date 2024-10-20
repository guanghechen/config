---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "cwd",
  condition = function()
    local devmode = eve.context.state.flight.devmode:snapshot() ---@type boolean
    return devmode
  end,
  render = function()
    local text = "  devmode " ---@type string
    local hl_text = eve.nvimbar.txt(text, "f_tl_devmode") ---@type string
    local width = vim.api.nvim_strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
