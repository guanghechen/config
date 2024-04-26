local ui = require("ghc.setting.ui")
local path = require("ghc.util.path")

--- @class ghc.ui.statusline.component.cwd
local M = {
  name = "ghc_statusline_cwd",
}

M.color = {
  icon = {
    fg = "black",
    bg = "vibrant_green",
  },
  separator = {
    fg = "vibrant_green",
    bg = "lightbg",
  },
  separator_leftest = {
    fg = "vibrant_green",
    bg = ui.transparency and "none" or "statusline_bg",
  },
  text = {
    fg = "white",
    bg = ui.transparency and "none" or "statusline_bg",
  },
}

function M.condition()
  return vim.o.columns > 85
end

---@param opts { is_leftest: boolean }
function M.renderer_right(opts)
  local is_leftest = opts.is_leftest
  local cwd = path.cwd()
  local cwd_name = (cwd:match("([^/\\]+)[/\\]*$") or cwd)

  local color_separator = "%#" .. M.name .. (is_leftest and "_separator_leftest#" or "_separator#")
  local color_icon = "%#" .. M.name .. "_icon#"
  local color_text = "%#" .. M.name .. "_text#"

  local separator = ui.statusline.symbol.separator.left
  local icon = "󰉋 "
  local text = " " .. cwd_name .. " "
  return color_separator .. separator .. color_icon .. icon .. color_text .. text
end

return M
