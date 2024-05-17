local icons = require("ghc.core.setting.icons")

local context = {
  config = require("ghc.core.context.config"),
}

---@type boolean
local transparency = context.config.transparency:get_snapshot()

--- @class ghc.ui.statusline.component.pos
local M = {
  name = "ghc_statusline_pos",
  color = {
    text = {
      fg = "white",
      bg = transparency and "none" or "statusline_bg",
    },
  },
}

function M.condition()
  return true
end

function M.renderer()
  local color_text = "%#" .. M.name .. "_text#"
  local text = " " .. icons.ui.Location .. " %l·%c "
  return color_text .. text
end

return M
