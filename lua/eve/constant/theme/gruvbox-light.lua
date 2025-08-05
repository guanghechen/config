---@type std.t.theme.IScheme
local M = {
  theme = "gruvbox",
  variant = "light",
  opposite = "dark",
  darken = false,
  -- stylua: ignore start
  palette = {
    none =            "none",

    bg0 =             "#FBF1C7",
    bg1 =             "#EBDBB2",
    bg2 =             "#D5C4A1",
    bg3 =             "#BDAE93",
    bg4 =             "#A89984",

    fg0 =             "#282828",
    fg1 =             "#3C3836",
    fg2 =             "#504945",
    fg3 =             "#665C54",
    fg4 =             "#7C6F64",

    red =             "#9D0006",
    green =           "#79740E",
    yellow =          "#B57614",
    blue =            "#076678",
    purple =          "#8F3F71",
    aqua =            "#427B58",
    orange =          "#AF3A03",

    brightRed =       "#CC241D",
    brightGreen =     "#98971A",
    brightYellow =    "#D79921",
    brightBlue =      "#458588",
    brightPurple =    "#B16286",
    brightAqua =      "#689D6A",
    brightOrange =    "#D65D0E",

    grey =            "#928374",
    pink =            "#8F3F71",

    diffDel =         "#FCC19F",
    diffDelInline =   "#EB9D82",
    diffAdd =         "#E8E6B0",
    diffAddInline =   "#D3D192",
  },
  -- stylua: ignore end
}

return M
