local ui = require("ghc.setting.ui")

local function get_neotree_width()
  for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].ft == "neo-tree" then
      return vim.api.nvim_win_get_width(win) + 1
    end
  end
  return 0
end

--- @class ghc.ui.bufferline.component.neotree
local M = {
  name = "ghc_bufferline_neotree",
}

M.color = {
  blank = {
    fg = "white",
    bg = ui.transparency and "none" or "black2",
  },
  icon = {
    fg = "white",
    bg = "black2",
  },
  text = {
    fg = "white",
    bg = ui.transparency and "none" or "black2",
  },
}

function M.condition()
  return true
end

function M.renderer_left()
  local width = get_neotree_width()
  if width <= 0 then
    return ""
  end

  local color_blank = "%#" .. M.name .. "_blank#"
  local color_icon = "%#" .. M.name .. "_icon#"
  local color_text = "%#" .. M.name .. "_text#"

  local icon = " "
  local text = "Explorer"
  local word_size = #(icon .. text)
  local left_width = math.floor((width - word_size) / 2)
  local right_width = width - left_width - word_size
  local left_blank = string.rep(" ", left_width)
  local right_blank = string.rep(" ", right_width)

  return color_blank .. left_blank .. color_icon .. icon .. color_text .. text .. color_blank .. right_blank
end

return M
