local username = os.getenv("USER") or os.getenv("USERNAME") or "unknown" ---@type string

---@type fml.t.ux.nvimbar.IRawComponent
local M = {
  name = "username",
  ---@diagnostic disable-next-line: unused-local
  will_change = function(context, prev_context)
    return prev_context == nil
  end,
  render = function()
    local icon = eve.icons.os.current ---@type string
    local text = " " .. icon .. " " .. username .. " " ---@type string
    local hl_text = eve.nvimbar.txt(text, "f_sl_username") ---@type string
    local width = vim.api.nvim_strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
