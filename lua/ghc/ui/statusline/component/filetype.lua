local ui = require("ghc.core.setting.ui")
local calc_fileicon = require("ghc.core.util.filetype").calc_fileicon

--- @class ghc.ui.statusline.component.filetype
local M = {
  name = "ghc_statusline_filetype",
}

M.color = {
  icon = {
    fg = "black",
    bg = "red",
  },
  separator = {
    fg = "red",
    bg = "lightbg",
  },
  separator_leftest = {
    fg = "red",
    bg = ui.transparency and "none" or "statusline_bg",
  },
  text = {
    fg = "white",
    bg = ui.transparency and "none" or "statusline_bg",
  },
}

function M.condition()
  local filetype = vim.bo.filetype
  return filetype and #filetype > 0
end

---@param opts { is_leftest: boolean }
function M.renderer_right(opts)
  local is_leftest = opts.is_leftest
  local filetype = vim.bo.filetype
  local filepath = vim.fn.expand("%:p")

  local color_separator = "%#" .. M.name .. (is_leftest and "_separator_leftest#" or "_separator#")
  local color_icon = "%#" .. M.name .. "_icon#"
  local color_text = "%#" .. M.name .. "_text#"

  local separator = ui.statusline.symbol.separator.left
  local icon = calc_fileicon(filepath) .. " "
  local text = " " .. filetype .. " "
  return color_separator .. separator .. color_icon .. icon .. color_text .. text
end

return M
