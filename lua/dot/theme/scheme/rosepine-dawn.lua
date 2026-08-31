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

      fg0           = "#464261",
      fg1           = "#464261",
      fg2           = "#797593",
      fg3           = "#9893A5",
      fg4           = "#9893A5",

      red           = "#B4637A",
      green         = "#286983",
      yellow        = "#EA9D34",
      blue          = "#56949F",
      purple        = "#907AA9",
      aqua          = "#D7827E",
      orange        = "#D7827E",

      brightRed     = "#B4637A",
      brightGreen   = "#286983",
      brightYellow  = "#EA9D34",
      brightBlue    = "#56949F",
      brightPurple  = "#907AA9",
      brightAqua    = "#D7827E",
      brightOrange  = "#D7827E",

      grey          = "#9893A5",
      pink          = "#B4637A",

      diffDel       = "#ECD7D6",
      diffDelInline = "#DEBABF",
      diffAdd       = "#D9E1DD",
      diffAddInline = "#B8CECE",
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
      text          = "#464261",
    },
  },
  -- stylua: ignore end
}

return M
