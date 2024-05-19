local context_config = require("ghc.core.context.config")

---@type boolean
local transparency = context_config.transparency:get_snapshot()

--- @class ghc.ui.statusline.component.bg
local M = {
  name = "ghc_statusline_bg",
}

M.color = {
  text = {
    fg = transparency and "none" or "statusline_bg",
    bg = transparency and "none" or "statusline_bg",
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
