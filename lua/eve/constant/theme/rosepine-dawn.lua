---@type std.t.theme.IScheme
local M = {
  theme = "rosepine",
  variant = "dawn",
  opposite = "main",
  darken = false,
  -- stylua: ignore start
  palette = {
    none =            "none",

    bg0 =             "#FAF4ED",
    bg1 =             "#FFFAF3",
    bg2 =             "#F2E9E1",
    bg3 =             "#DFDAD9",
    bg4 =             "#CECACD",

    fg0 =             "#464261",
    fg1 =             "#464261",
    fg2 =             "#797593",
    fg3 =             "#9893A5",
    fg4 =             "#9893A5",

    red =             "#B4637A",
    green =           "#6D8F89",
    yellow =          "#EA9D34",
    blue =            "#286983",
    purple =          "#907AA9",
    aqua =            "#56949F",
    orange =          "#D7827E",

    brightRed =       "#B4637A",
    brightGreen =     "#6D8F89",
    brightYellow =    "#EA9D34",
    brightBlue =      "#286983",
    brightPurple =    "#907AA9",
    brightAqua =      "#56949F",
    brightOrange =    "#D7827E",

    grey =            "#9893A5",
    pink =            "#B4637A",

    diffDel =         "#F5D8E0",
    diffDelInline =   "#F0C6D2",
    diffAdd =         "#E4EBE4",
    diffAddInline =   "#D5E0D5",
  },
  -- stylua: ignore end
}

return M
