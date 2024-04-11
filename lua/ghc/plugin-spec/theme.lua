return {
  {
    -- Make TokyoNight Transparent
    -- https://www.lazyvim.org/configuration/recipes#make-tokyonight-transparent
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },
}
