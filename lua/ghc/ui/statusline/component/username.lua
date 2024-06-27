local function get_os_icon()
  if fml.os.is_mac() then
    return fml.ui.icons.os.mac
  elseif fml.os.is_windows() then
    return fml.ui.icons.os.dos
  elseif fml.os.is_linux() or fml.os.is_wsl() then
    return fml.ui.icons.os.unix
  else
    return fml.ui.icons.os.unknown
  end
end

---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "username",
  will_change = function (context, prev_context)
    return prev_context == nil
  end,
  pieces = {
    {
      hlname = function()
        return "f_sl_username"
      end,
      text = function()
        local icon = get_os_icon()
        local username = os.getenv("USER") or os.getenv("USERNAME") or "unknown"
        return " " .. icon .. " " .. username .. " "
      end,
    },
  },
}

return M
