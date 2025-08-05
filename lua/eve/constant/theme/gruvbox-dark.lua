---@type std.t.theme.IScheme
local M = {
  theme = "gruvbox",
  variant = "dark",
  opposite = "light",
  darken = true,
  -- stylua: ignore start
  palette = {
    none =            "none",

    bg0 =             "#282828",
    bg1 =             "#3C3836",
    bg2 =             "#504945",
    bg3 =             "#665C54",
    bg4 =             "#7C6F64",

    fg0 =             "#FBF1C7",
    fg1 =             "#EBDBB2",
    fg2 =             "#D5C4A1",
    fg3 =             "#BDAE93",
    fg4 =             "#A89984",

    red =             "#FB4934",
    green =           "#B8BB26",
    yellow =          "#FABD2F",
    blue =            "#83A598",
    purple =          "#D3869B",
    aqua =            "#8EC07C",
    orange =          "#FE8019",

    brightRed =       "#CC241D",
    brightGreen =     "#98971A",
    brightYellow =    "#D79921",
    brightBlue =      "#458588",
    brightPurple =    "#B16286",
    brightAqua =      "#689D6A",
    brightOrange =    "#D65D0E",

    grey =            "#928374",
    pink =            "#D3869B",

    diffDel =         "#532020",
    diffDelInline =   "#722824",
    diffAdd =         "#565B2F",
    diffAddInline =   "#3F4531",
  },
  -- stylua: ignore end
}

return M
