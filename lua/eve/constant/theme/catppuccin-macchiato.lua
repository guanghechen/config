---@type std.t.theme.IScheme
local M = {
  theme = "catppuccin",
  variant = "macchiato",
  opposite = "latte",
  darken = true,
  -- stylua: ignore start
  palette = {
    unified = {
      none          = "none",

      bg0           = "#24273A",
      bg1           = "#1E2030",
      bg2           = "#363A4F",
      bg3           = "#494D64",
      bg4           = "#5B6078",

      fg0           = "#CAD3F5",
      fg1           = "#B8C0E0",
      fg2           = "#A5ADCB",
      fg3           = "#939AB7",
      fg4           = "#8087A2",

      red           = "#ED8796",
      green         = "#A6DA95",
      yellow        = "#EED49F",
      blue          = "#8AADF4",
      purple        = "#C6A0F6",
      aqua          = "#8BD5CA",
      orange        = "#F5A97F",

      brightRed     = "#ED8796",
      brightGreen   = "#A6DA95",
      brightYellow  = "#EED49F",
      brightBlue    = "#8AADF4",
      brightPurple  = "#C6A0F6",
      brightAqua    = "#8BD5CA",
      brightOrange  = "#F5A97F",

      grey          = "#6E738D",
      pink          = "#F5BDE6",

      diffDel       = "#3A273A",
      diffDelInline = "#8B3A3A",
      diffAdd       = "#2A3A2A",
      diffAddInline = "#4A6E4A",
    },
    catppuccin = {
      none          = "none",

      base          = "#24273A",
      blue          = "#8AADF4",
      crust         = "#181926",
      flamingo      = "#F0C6C6",
      green         = "#A6DA95",
      lavender      = "#B7BDF8",
      mantle        = "#1E2030",
      maroon        = "#EE99A0",
      mauve         = "#C6A0F6",
      overlay0      = "#6E738D",
      overlay1      = "#8087A2",
      overlay2      = "#939AB7",
      peach         = "#F5A97F",
      pink          = "#F5BDE6",
      red           = "#ED8796",
      rosewater     = "#F4DBD6",
      sapphire      = "#7DC4E4",
      sky           = "#91D7E3",
      subtext0      = "#A5ADCB",
      subtext1      = "#B8C0E0",
      surface0      = "#363A4F",
      surface1      = "#494D64",
      surface2      = "#5B6078",
      teal          = "#8BD5CA",
      text          = "#CAD3F5",
      yellow        = "#EED49F",
    },
  },
  -- stylua: ignore end
}

return M
