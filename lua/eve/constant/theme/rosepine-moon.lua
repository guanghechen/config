---@type std.t.theme.IScheme
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
      green         = "#95B1AC",
      yellow        = "#F6C177",
      blue          = "#3E8FB0",
      purple        = "#C4A7E7",
      aqua          = "#9CCFD8",
      orange        = "#EA9A97",

      brightRed     = "#EB6F92",
      brightGreen   = "#95B1AC",
      brightYellow  = "#F6C177",
      brightBlue    = "#3E8FB0",
      brightPurple  = "#C4A7E7",
      brightAqua    = "#9CCFD8",
      brightOrange  = "#EA9A97",

      grey          = "#908CAA",
      pink          = "#EB6F92",

      diffDel       = "#362436",
      diffDelInline = "#442430",
      diffAdd       = "#2A3645",
      diffAddInline = "#254055",
    },
    rosepine = {
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
