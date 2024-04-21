return {
  -- util library
  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },

  -- icons
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
    config = function() 
      dofile(vim.g.base46_cache .. "devicons")
      require("nvim-web-devicons").setup({
        override = require("nvchad.icons.devicons")
      })
    end
  },

  -- ui components
  {
    "MunifTanjim/nui.nvim",
    lazy = true,
  },
}