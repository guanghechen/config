---@type std.t.theme.IScheme
local M = {
  theme = "catppuccin",
  variant = "mocha",
  opposite = "macchiato",
  darken = true,
  -- stylua: ignore start
  palette = {
    unified = {
      none          = "none",

      bg0           = "#1E1E2E",
      bg1           = "#11111B",
      bg2           = "#313244",
      bg3           = "#45475A",
      bg4           = "#585B70",

      fg0           = "#B4BEFE",
      fg1           = "#CDD6F4",
      fg2           = "#BAC2DE",
      fg3           = "#A6ADC8",
      fg4           = "#9399B2",

      red           = "#F38BA8",
      green         = "#A6E3A1",
      yellow        = "#F9E2AF",
      blue          = "#89B4FA",
      purple        = "#CBA6F7",
      aqua          = "#94E2D5",
      orange        = "#FAB387",

      brightRed     = "#F38BA8",
      brightGreen   = "#A6E3A1",
      brightYellow  = "#F9E2AF",
      brightBlue    = "#89B4FA",
      brightPurple  = "#CBA6F7",
      brightAqua    = "#94E2D5",
      brightOrange  = "#FAB387",

      grey          = "#7F849C",
      pink          = "#F5C2E7",

      diffDel       = "#362424",
      diffDelInline = "#833535",
      diffAdd       = "#293232",
      diffAddInline = "#476E6E",
    },
    catppuccin = {
      base          = "#1E1E2E",
      blue          = "#89B4FA",
      crust         = "#11111B",
      flamingo      = "#F2CDCD",
      green         = "#A6E3A1",
      lavender      = "#B4BEFE",
      mantle        = "#181825",
      maroon        = "#EBA0AC",
      mauve         = "#CBA6F7",
      overlay0      = "#6C7086",
      overlay1      = "#7F849C",
      overlay2      = "#9399B2",
      peach         = "#FAB387",
      pink          = "#F5C2E7",
      red           = "#F38BA8",
      rosewater     = "#F5E0DC",
      sapphire      = "#74C7EC",
      sky           = "#89DCEB",
      subtext0      = "#A6ADC8",
      subtext1      = "#BAC2DE",
      surface0      = "#313244",
      surface1      = "#45475A",
      surface2      = "#585B70",
      teal          = "#94E2D5",
      text          = "#CDD6F4",
      yellow        = "#F9E2AF",
    },
  },
  -- stylua: ignore end
}

return M
