-- https://github.com/NvChad/base46/blob/adb64a6ae70f8c61c5ab8892f07d29dafd4d47ad/lua/base46/themes/onedark.lua

---@type fml.types.ui.theme.IScheme
local M = {
  mode = "darken",
  colors = {
    white = "#abb2bf",
    darker_black = "#1b1f27",
    black = "#1e222a", --  nvim bg
    black2 = "#252931",
    one_bg = "#282c34", -- real bg of onedark
    one_bg2 = "#353b45",
    one_bg3 = "#373b43",
    grey = "#42464e",
    grey_fg = "#565c64",
    grey_fg2 = "#6f737b",
    light_grey = "#6f737b",
    red = "#e06c75",
    baby_pink = "#DE8C92",
    pink = "#ff75a0",
    line = "#31353d", -- for lines like vertsplit
    green = "#98c379",
    vibrant_green = "#7eca9c",
    nord_blue = "#81A1C1",
    blue = "#61afef",
    yellow = "#e7c787",
    sun = "#EBCB8B",
    purple = "#de98fd",
    dark_purple = "#c882e7",
    teal = "#519ABA",
    orange = "#fca2aa",
    cyan = "#a3b8ef",
    statusline_bg = "#22262e",
    lightbg = "#2d3139",
    pmenu_bg = "#61afef",
    folder_bg = "#61afef",
    diff_delete = "#FFE0E0",
    diff_delete_hl = "#FFC0C0",
    diff_add = "#D0FFD0",
    diff_add_hl = "#A0EFA0",
  },
}

return M