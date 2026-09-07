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
      fg2           = "#A5A0BB",
      fg3           = "#6E6A86",
      fg4           = "#6E6A86",

      red           = "#F080A0",
      green         = "#75ADC1",
      yellow        = "#F6C177",
      blue          = "#9CCFD8",
      purple        = "#C4A7E7",
      aqua          = "#EA9A97",
      orange        = "#EA9A97",

      brightRed     = "#F080A0",
      brightGreen   = "#75ADC1",
      brightYellow  = "#F6C177",
      brightBlue    = "#9CCFD8",
      brightPurple  = "#C4A7E7",
      brightAqua    = "#EA9A97",
      brightOrange  = "#EA9A97",

      grey          = "#A5A0BB",
      pink          = "#F080A0",

      diffDel       = "#3A293B",
      diffDelInline = "#594056",
      diffAdd       = "#2E3B46",
      diffAddInline = "#405563",
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
