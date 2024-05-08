local ui = require("ghc.core.setting.ui")

--- @class ghc.ui.statusline.component.bg
local M = {
  name = "ghc_statusline_bg",
}

M.color = {
  text = {
    fg = ui.transparency and "none" or "statusline_bg",
    bg = ui.transparency and "none" or "statusline_bg",
  },
}

function M.condition()
  return true
end

function M.renderer()
  local color_text = "%#" .. M.name .. "_text#"
  return color_text .. " "
end

return M
