--- rosepine-dawn

---@type stl.t.theme.IScheme
local M = {
  theme = "rosepine",
  variant = "dawn",
  opposite = "main",
  darken = false,
  -- stylua: ignore start
  palette = {
    unified = {
      none          = "none",

      bg0           = "#FAF4ED",
      bg1           = "#FFFAF3",
      bg2           = "#F2E9E1",
      bg3           = "#DFDAD9",
      bg4           = "#CECACD",

      fg0           = "#2C283B",
      fg1           = "#2C283B",
      fg2           = "#545064",
      fg3           = "#6C667B",
      fg4           = "#6C667B",

      red           = "#8A344D",
      green         = "#205569",
      yellow        = "#714A12",
      blue          = "#235965",
      purple        = "#634873",
      aqua          = "#853C3A",
      orange        = "#853C3A",

      brightRed     = "#8A344D",
      brightGreen   = "#205569",
      brightYellow  = "#714A12",
      brightBlue    = "#235965",
      brightPurple  = "#634873",
      brightAqua    = "#853C3A",
      brightOrange  = "#853C3A",

      grey          = "#545064",
      pink          = "#8A344D",

      diffDel       = "#F5E7E5",
      diffDelInline = "#E4C9CB",
      diffAdd       = "#E4ECE7",
      diffAddInline = "#CBDDD6",
    },
    rosepine = {
      none          = "none",

      base          = "#FAF4ED",
      foam          = "#56949F",
      gold          = "#EA9D34",
      highlightHigh = "#CECACD",
      highlightLow  = "#F4EDE8",
      highlightMed  = "#DFDAD9",
      iris          = "#907AA9",
      love          = "#B4637A",
      muted         = "#9893A5",
      overlay       = "#F2E9E1",
      pine          = "#286983",
      rose          = "#D7827E",
      subtle        = "#797593",
      surface       = "#FFFAF3",
      text          = "#575279",
    },
  },
  -- stylua: ignore end
}

return M
