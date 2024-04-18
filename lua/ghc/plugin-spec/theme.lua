return {
  {
    -- Make TokyoNight Transparent
    -- https://www.lazyvim.org/configuration/recipes#make-tokyonight-transparent
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      style = "night",
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },

  -- Configure catppuccin
  {
    "catppuccin/nvim",
    name = "catppuccin",
    flavor = "auto",
    background = {
      light = "latte",
      dark = "mocha",
    },
  },
}
