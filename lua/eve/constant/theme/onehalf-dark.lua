---@type std.t.theme.IScheme
local M = {
  theme = "onehalf",
  variant = "dark",
  opposite = "light",
  darken = true,
  -- stylua: ignore start
  palette = {
    none =            "none",

    bg0 =             "#1E222A",
    bg1 =             "#252931",
    bg2 =             "#3E4451",
    bg3 =             "#545862",
    bg4 =             "#565C64",

    fg0 =             "#E5E9F0",
    fg1 =             "#D7DAE0",
    fg2 =             "#C8CCD4",
    fg3 =             "#B6BDCA",
    fg4 =             "#ABB2BF",

    red =             "#E06C75",
    green =           "#98C379",
    yellow =          "#E5C07B",
    blue =            "#61AFEF",
    purple =          "#C678DD",
    aqua =            "#56B6C2",
    orange =          "#D75F00",

    brightRed =       "#E06C75",
    brightGreen =     "#7ECA9C",
    brightYellow =    "#D19A66",
    brightBlue =      "#61AFEF",
    brightPurple =    "#B294BB",
    brightAqua =      "#4EC9B0",
    brightOrange =    "#FE8655",

    grey =            "#42464E",
    pink =            "#DE8C92",

    diffDel =         "#53232A",
    diffDelInline =   "#751C22",
    diffAdd =         "#3F483B",
    diffAddInline =   "#32544E",
  },
  -- stylua: ignore end
}

return M
