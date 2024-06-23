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

--- @class ghc.ui.statusline.component.username
local M = {
  name = "ghc_statusline_username",
  color = {
    text = {
      fg = "black",
      bg = "cyan",
    },
  },
}

function M.condition()
  return true
end

function M.renderer()
  local username = os.getenv("USER") or os.getenv("USERNAME") or "unknown"
  local color_text = "%#" .. M.name .. "_text#"
  local icon = get_os_icon()
  local text = " " .. icon .. " " .. username .. " "
  return color_text .. text
end

return M
