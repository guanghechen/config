local function get_os_icon()
  if eve.os.is_mac() then
    return fml.ui.icons.os.mac
  elseif eve.os.is_win() then
    return fml.ui.icons.os.dos
  elseif eve.os.is_nix() or eve.os.is_wsl() then
    return fml.ui.icons.os.unix
  else
    return fml.ui.icons.os.unknown
  end
end

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "username",
  ---@diagnostic disable-next-line: unused-local
  will_change = function(context, prev_context)
    return prev_context == nil
  end,
  render = function()
    local icon = get_os_icon() ---@type string
    local username = os.getenv("USER") or os.getenv("USERNAME") or "unknown" ---@type string
    local text = " " .. icon .. " " .. username .. " " ---@type string
    local hl_text = eve.nvimbar.txt(text, "f_sl_username") ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
