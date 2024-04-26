local ui = require("ghc.setting.ui")

--- @class ghc.ui.statusline.component.pos
local M = {}

M.name = "ghc_statusline_pos"

M.color = {
  icon = {
    fg = "black",
    bg = "green",
  },
  separator = {
    fg = "green",
    bg = "statusline_bg",
  },
  separator_leftest = {
    fg = "green",
    bg = ui.transparency and "none" or "statusline_bg",
  },
  text = {
    fg = "black",
    bg = "green",
  },
}

function M.condition()
  return true
end

---@param opts { is_leftest: boolean }
function M.renderer_right(opts)
  local is_leftest = opts.is_leftest

  local color_separator = "%#" .. M.name .. (is_leftest and "_separator_leftest#" or "_separator#")
  local color_icon = "%#" .. M.name .. "_icon#"
  local color_text = "%#" .. M.name .. "_text#"

  local separator = ui.statusline.symbol.separator.left
  local icon = " "
  local text = " %l·%c "
  return color_separator .. separator .. color_icon .. icon .. color_text .. text
end

return M
