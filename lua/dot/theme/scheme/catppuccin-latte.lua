--- catppuccin-latte

---@type stl.t.theme.IScheme
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
      bg1           = "#E6E9EF",
      bg2           = "#DCE0E8",
      bg3           = "#CCD0DA",
      bg4           = "#BCC0CC",

      fg0           = "#303446",
      fg1           = "#303446",
      fg2           = "#4C4F69",
      fg3           = "#5C5F77",
      fg4           = "#6C6F85",

      red           = "#AD1635",
      green         = "#25651C",
      yellow        = "#7B4D0D",
      blue          = "#2451B5",
      purple        = "#722FBC",
      aqua          = "#106168",
      orange        = "#973C0F",

      brightRed     = "#AD1635",
      brightGreen   = "#25651C",
      brightYellow  = "#7B4D0D",
      brightBlue    = "#2451B5",
      brightPurple  = "#722FBC",
      brightAqua    = "#106168",
      brightOrange  = "#973C0F",

      grey          = "#5C5F77",
      pink          = "#91377D",

      diffDel       = "#ECDAE2",
      diffDelInline = "#E9BFCC",
      diffAdd       = "#DEE9E1",
      diffAddInline = "#C9DFC9",
    },
    catppuccin = {
      none          = "none",

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
