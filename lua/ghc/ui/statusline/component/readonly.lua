local icons = require("ghc.core.setting.icons")

local context = {
  config = require("ghc.core.context.config"),
}

---@type boolean
local transparency = context.config.transparency:get_snapshot()

--- @class ghc.ui.statusline.component.readonly
local M = {
  name = "ghc_statusline_readonly",
  color = {
    text = {
      fg = "orange",
      bg = transparency and "none" or "statusline_bg",
    },
  },
}

function M.condition()
  local readonly = vim.api.nvim_get_option_value("readonly", { buf = 0 }) ---@type boolean
  return readonly
end

function M.renderer()
  local color_text = "%#" .. M.name .. "_text#"
  local text = " " .. icons.ui.Lock .. " [RO] "
  return color_text .. text
end

return M
