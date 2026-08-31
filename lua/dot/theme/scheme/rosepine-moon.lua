--- rosepine-moon

---@type stl.t.theme.IScheme
local M = {
  theme = "rosepine",
  variant = "moon",
  opposite = "dawn",
  darken = true,
  -- stylua: ignore start
  palette = {
    unified = {
      none          = "none",

      bg0           = "#232136",
      bg1           = "#2A273F",
      bg2           = "#393552",
      bg3           = "#44415A",
      bg4           = "#56526E",

      fg0           = "#E0DEF4",
      fg1           = "#E0DEF4",
      fg2           = "#908CAA",
      fg3           = "#6E6A86",
      fg4           = "#6E6A86",

      red           = "#EB6F92",
      green         = "#3E8FB0",
      yellow        = "#F6C177",
      blue          = "#9CCFD8",
      purple        = "#C4A7E7",
      aqua          = "#EA9A97",
      orange        = "#EA9A97",

      brightRed     = "#EB6F92",
      brightGreen   = "#3E8FB0",
      brightYellow  = "#F6C177",
      brightBlue    = "#9CCFD8",
      brightPurple  = "#C4A7E7",
      brightAqua    = "#EA9A97",
      brightOrange  = "#EA9A97",

      grey          = "#6E6A86",
      pink          = "#EB6F92",

      diffDel       = "#4B3148",
      diffDelInline = "#73405B",
      diffAdd       = "#3B4456",
      diffAddInline = "#536777",
    },
    rosepine = {
      none          = "none",

      base          = "#232136",
      foam          = "#9CCFD8",
      gold          = "#F6C177",
      highlightHigh = "#56526E",
      highlightLow  = "#2A283E",
      highlightMed  = "#44415A",
      iris          = "#C4A7E7",
      love          = "#EB6F92",
      muted         = "#6E6A86",
      overlay       = "#393552",
      pine          = "#3E8FB0",
      rose          = "#EA9A97",
      subtle        = "#908CAA",
      surface       = "#2A273F",
      text          = "#E0DEF4",
    },
  },
  -- stylua: ignore end
}

return M
