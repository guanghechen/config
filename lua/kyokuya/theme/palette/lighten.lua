---@class kyokuya.theme.lighten : fml.types.api.highlight.IPalette
local M = {}

---@type fml.enums.highlight.Theme
M.scheme = "lighten"

---@type fml.types.api.highlight.IColors
M.colors = {
  white = "#54555b",
  darker_black = "#efeff0",
  black = "#fafafa", --  nvim bg
  black2 = "#EAEAEB",
  one_bg = "#dadadb", -- real bg of onedark
  one_bg2 = "#d4d4d5",
  one_bg3 = "#cccccd",
  grey = "#b7b7b8",
  grey_fg = "#b0b0b1",
  grey_fg2 = "#a9a9aa",
  light_grey = "#a2a2a3",
  red = "#d84a3d",
  baby_pink = "#F07178",
  pink = "#ff75a0",
  line = "#e2e2e2", -- for lines like vertsplit
  green = "#50a14f",
  vibrant_green = "#7eca9c",
  nord_blue = "#428bab",
  blue = "#4078f2",
  yellow = "#c18401",
  sun = "#dea95f",
  purple = "#a28dcd",
  dark_purple = "#8e79b9",
  teal = "#519ABA",
  orange = "#FF6A00",
  cyan = "#0b8ec6",
  statusline_bg = "#ececec",
  lightbg = "#d3d3d3",
  pmenu_bg = "#5e5f65",
  folder_bg = "#6C6C6C",
  diff_delete = "#FFE0E0",
  diff_add = "#D0FFD0",
  diff_delete_hl = "#FFC0C0",
  diff_add_hl = "#A0EFA0",
}

return M
