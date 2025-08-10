--- rosepine-main

---@type std.t.theme.IScheme
local M = {
  theme = "rosepine",
  variant = "main",
  opposite = "dawn",
  darken = true,
  -- stylua: ignore start
  palette = {
    unified = {
      none          = "none",

      bg0           = "#191724",
      bg1           = "#1F1D2E",
      bg2           = "#26233A",
      bg3           = "#403D52",
      bg4           = "#524F67",

      fg0           = "#E0DEF4",
      fg1           = "#E0DEF4",
      fg2           = "#908CAA",
      fg3           = "#6E6A86",
      fg4           = "#6E6A86",

      red           = "#EB6F92",
      green         = "#95B1AC",
      yellow        = "#F6C177",
      blue          = "#31748F",
      purple        = "#C4A7E7",
      aqua          = "#9CCFD8",
      orange        = "#EBBCBA",

      brightRed     = "#EB6F92",
      brightGreen   = "#95B1AC",
      brightYellow  = "#F6C177",
      brightBlue    = "#31748F",
      brightPurple  = "#C4A7E7",
      brightAqua    = "#9CCFD8",
      brightOrange  = "#EBBCBA",

      grey          = "#908CAA",
      pink          = "#EB6F92",

      diffDel       = "#362434",
      diffDelInline = "#44242E",
      diffAdd       = "#2A3440",
      diffAddInline = "#25404F",
    },
    rosepine = {
      none          = "none",

      base          = "#191724",
      foam          = "#9CCFD8",
      gold          = "#F6C177",
      highlightHigh = "#524F67",
      highlightLow  = "#21202E",
      highlightMed  = "#403D52",
      iris          = "#C4A7E7",
      love          = "#EB6F92",
      muted         = "#6E6A86",
      overlay       = "#26233A",
      pine          = "#31748F",
      rose          = "#EBBCBA",
      subtle        = "#908CAA",
      surface       = "#1F1D2E",
      text          = "#E0DEF4",
    },
  },
  -- stylua: ignore end
}

return M
