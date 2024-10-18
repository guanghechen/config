-- https://github.com/navarasu/onedark.nvim/blob/master/lua/onedark/palette.lua

---@type fml.types.ui.theme.IScheme
local M = {
  name = "one_half_dark",
  mode = "darken",
  palette = {
    black = "#282C34",
    blue = "#61AFEF",
    cyan = "#56B6C2",
    green = "#98C379",
    grey = "#5c6370",
    lavender = "#C7D1FF",
    pink = "#DE8C92",
    purple = "#C678DD",
    red = "#E06C75",
    white = "#ABB2BF",
    yellow = "#E5C07B",
    dark_black = "#1B1F27",
    dark_blue = "#61AFEF",
    dark_cyan = "#2B6F77",
    dark_green = "#98C379",
    dark_pink = "#AC719B",
    dark_purple = "#A284E0",
    dark_red = "#BE5046",
    dark_white = "#ABB2BF",
    dark_yellow = "#D19A66",

    bg0 = "#1B1F27",
    bg1 = "#282C34",
    bg2 = "#31353f",
    bg3 = "#393f4a",
    bg_blue = "#73B8F1",
    bg_cyan = "#A3B8EF",
    bg_pink = "#B57CA5",
    bg_yellow = "#EBD09C",
    fg0 = "#C8CCD4",
    fg1 = "#ABB2BF",
    fg2 = "#848b98",
    fg3 = "#5c6370",

    diff_add = "#D0FFD0",
    diff_add_word = "#A0EFA0",
    diff_del = "#FFE0E0",
    diff_del_word = "#FFC0C0",
  },
}

return M
