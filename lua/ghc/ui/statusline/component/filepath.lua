local ui = require("ghc.setting.ui")
local path = require("ghc.util.path")
local calc_fileicon = require("ghc.util.filetype").calc_fileicon

--- @class ghc.ui.statusline.component.filepath
local M = {
  name = "ghc_statusline_filepath",
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
  separator_rightest = {
    fg = "red",
    bg = ui.transparency and "none" or "statusline_bg",
  },
  text = {
    fg = "white",
    bg = ui.transparency and "none" or "statusline_bg",
  },
}

function M.condition()
  local filepath = vim.fn.expand("%:p")
  if not filepath or #filepath == 0 then
    return false
  end

  local relative_path = path.relative(path.cwd(), filepath)
  return relative_path ~= "."
end

---@param opts { is_rightest: boolean }
function M.renderer_left(opts)
  local is_rightest = opts.is_rightest
  local filepath = vim.fn.expand("%:p")
  local relative_path = path.relative(path.cwd(), filepath)

  local color_separator = "%#" .. M.name .. (is_rightest and "_separator_rightest#" or "_separator#")
  local color_icon = "%#" .. M.name .. "_icon#"
  local color_text = "%#" .. M.name .. "_text#"

  local separator = ui.statusline.symbol.separator.right
  local icon = " " .. calc_fileicon(filepath) .. " "
  local text = " " .. relative_path .. " "
  return color_icon .. icon .. color_text .. text .. color_separator .. separator
end

return M
