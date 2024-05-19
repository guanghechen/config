local util_os = require("guanghechen.util.os")
local icons = require("ghc.core.setting.icons")

local function get_os_icon()
  if util_os.is_mac() then
    return icons.os.mac
  elseif util_os.is_windows() then
    return icons.os.dos
  elseif util_os.is_linux() or util_os.is_wsl() then
    return icons.os.unix
  else
    return icons.os.unknown
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
