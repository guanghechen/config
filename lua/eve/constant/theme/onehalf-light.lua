---@type std.t.theme.IScheme
local M = {
  theme = "onehalf",
  variant = "light",
  opposite = "dark",
  darken = false,
  -- stylua: ignore start
  palette = {
    none =            "none",

    bg0 =             "#FAFAFA",
    bg1 =             "#F0F0F0",
    bg2 =             "#EAEAEA",
    bg3 =             "#DCDCDC",
    bg4 =             "#D3D3D3",

    fg0 =             "#767A83",
    fg1 =             "#696D75",
    fg2 =             "#5C5F66",
    fg3 =             "#4F525A",
    fg4 =             "#383A42",

    red =             "#D84A3D",
    green =           "#50A14F",
    yellow =          "#DEA95F",
    blue =            "#4078F2",
    purple =          "#A28DCD",
    aqua =            "#0B8EC6",
    orange =          "#FF6A00",

    brightRed =       "#E45649",
    brightGreen =     "#7ECA9C",
    brightYellow =    "#C18401",
    brightBlue =      "#4078F2",
    brightPurple =    "#B294BB",
    brightAqua =      "#4EC9B0",
    brightOrange =    "#FE8655",

    grey =            "#B7B7B7",
    pink =            "#F07178",

    diffDel =         "#FBBBBE",
    diffDelInline =   "#FBC8C8",
    diffAdd =         "#E7EDD9",
    diffAddInline =   "#D4ECCD",
  },
  -- stylua: ignore end
}

return M
