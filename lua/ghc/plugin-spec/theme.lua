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
    enabled = false,
    background = {
      light = "latte",
      dark = "mocha",
    },
  },

  -- Configure papercolor
  {
    "yorik1984/newpaper.nvim",
    priority = 1000,
    opts = {
      style = "light",
    },
  },
}
