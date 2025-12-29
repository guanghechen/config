--- catppuccin-frappe

---@type stl.t.theme.IScheme
local M = {
  theme = "catppuccin",
  variant = "frappe",
  opposite = "mocha",
  darken = true,
  -- stylua: ignore start
  palette = {
    unified = {
      none          = "none",

      bg0           = "#303446",
      bg1           = "#232634",
      bg2           = "#414559",
      bg3           = "#51576D",
      bg4           = "#626880",

      fg0           = "#C6D0F5",
      fg1           = "#B5BFE2",
      fg2           = "#A5ADCE",
      fg3           = "#949CBB",
      fg4           = "#838BA7",

      red           = "#E78284",
      green         = "#A6D189",
      yellow        = "#E5C890",
      blue          = "#8CAAEE",
      purple        = "#F4B8E4",
      aqua          = "#81C8BE",
      orange        = "#EF9F76",

      brightRed     = "#E78284",
      brightGreen   = "#A6D189",
      brightYellow  = "#E5C890",
      brightBlue    = "#8CAAEE",
      brightPurple  = "#F4B8E4",
      brightAqua    = "#81C8BE",
      brightOrange  = "#EF9F76",

      grey          = "#626880",
      pink          = "#F4B8E4",

      diffDel       = "#4C3A3A",
      diffDelInline = "#3A2A2A",
      diffAdd       = "#3A4C3A",
      diffAddInline = "#2A3A2A",
    },
    catppuccin = {
      none          = "none",

      base          = "#303446",
      blue          = "#8CAAEE",
      crust         = "#232634",
      flamingo      = "#EEBEBE",
      green         = "#A6D189",
      lavender      = "#BABBF1",
      mantle        = "#292C3C",
      maroon        = "#EA999C",
      mauve         = "#CA9EE6",
      overlay0      = "#737994",
      overlay1      = "#838BA7",
      overlay2      = "#949CBB",
      peach         = "#EF9F76",
      pink          = "#F4B8E4",
      red           = "#E78284",
      rosewater     = "#F2D5CF",
      sapphire      = "#85C1DC",
      sky           = "#99D1DB",
      subtext0      = "#A5ADCE",
      subtext1      = "#B5BFE2",
      surface0      = "#414559",
      surface1      = "#51576D",
      surface2      = "#626880",
      teal          = "#81C8BE",
      text          = "#C6D0F5",
      yellow        = "#E5C890",
    },
  },
  -- stylua: ignore end
}

return M
