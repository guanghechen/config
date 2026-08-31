--- rosepine-main

---@type stl.t.theme.IScheme
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
      green         = "#31748F",
      yellow        = "#F6C177",
      blue          = "#9CCFD8",
      purple        = "#C4A7E7",
      aqua          = "#EBBCBA",
      orange        = "#EBBCBA",

      brightRed     = "#EB6F92",
      brightGreen   = "#31748F",
      brightYellow  = "#F6C177",
      brightBlue    = "#9CCFD8",
      brightPurple  = "#C4A7E7",
      brightAqua    = "#EBBCBA",
      brightOrange  = "#EBBCBA",

      grey          = "#6E6A86",
      pink          = "#EB6F92",

      diffDel       = "#43293A",
      diffDelInline = "#6D3A50",
      diffAdd       = "#333C48",
      diffAddInline = "#4D616C",
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
