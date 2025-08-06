---@type std.t.theme.IScheme
local M = {
  theme = "catppuccin",
  variant = "latte",
  opposite = "frappe",
  darken = false,
  -- stylua: ignore start
  palette = {
    unified = {
      none          = "none",

      bg0           = "#EFF1F5",
      bg1           = "#DCE0E8",
      bg2           = "#CCD0DA",
      bg3           = "#BCC0CC",
      bg4           = "#ACB0BE",

      fg0           = "#4C4F69",
      fg1           = "#5C5F77",
      fg2           = "#6C6F85",
      fg3           = "#7C7F93",
      fg4           = "#8C8FA1",

      red           = "#D20F39",
      green         = "#40A02B",
      yellow        = "#DF8E1D",
      blue          = "#1E66F5",
      purple        = "#8839EF",
      aqua          = "#179299",
      orange        = "#FE640B",

      brightRed     = "#E64553",
      brightGreen   = "#40A02B",
      brightYellow  = "#DF8E1D",
      brightBlue    = "#1E66F5",
      brightPurple  = "#8839EF",
      brightAqua    = "#179299",
      brightOrange  = "#FE640B",

      grey          = "#9CA0B0",
      pink          = "#EA76CB",

      diffDel       = "#E8CDD6",
      diffDelInline = "#E5BAC5",
      diffAdd       = "#D2E1D5",
      diffAddInline = "#C3D9C3",
    },
    catppuccin = {
      base          = "#EFF1F5",
      blue          = "#1E66F5",
      crust         = "#DCE0E8",
      flamingo      = "#DD7878",
      green         = "#40A02B",
      lavender      = "#7287FD",
      mantle        = "#E6E9EF",
      maroon        = "#E64553",
      mauve         = "#8839EF",
      overlay0      = "#9CA0B0",
      overlay1      = "#8C8FA1",
      overlay2      = "#7C7F93",
      peach         = "#FE640B",
      pink          = "#EA76CB",
      red           = "#D20F39",
      rosewater     = "#DC8A78",
      sapphire      = "#209FB5",
      sky           = "#04A5E5",
      subtext0      = "#6C6F85",
      subtext1      = "#5C5F77",
      surface0      = "#CCD0DA",
      surface1      = "#BCC0CC",
      surface2      = "#ACB0BE",
      teal          = "#179299",
      text          = "#4C4F69",
      yellow        = "#DF8E1D",
    },
  },
  -- stylua: ignore end
}

return M
