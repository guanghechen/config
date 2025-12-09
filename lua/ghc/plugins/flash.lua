---@see https://github.com/folke/folke/flash.nvim/tree/fcea7ff883235d9024dc41e638f164a450c14ca2

-- Flash enhances the built-in search functionality by showing labels
-- at the end of each match, letting you quickly jump to a specific location.
return {
  name = "flash.nvim",
  event = "VeryLazy",
  keys = {
    {
      "s",
      mode = { "n", "x", "o" },
      function()
        require("flash").jump()
      end,
      desc = "flash: jump",
    },
    {
      "S",
      mode = { "n", "o", "x" },
      function()
        require("flash").treesitter({
          label = { style = "overlay" },
          highlight = { backdrop = true },
        })
      end,
      desc = "flash: treesitter",
    },
    {
      "r",
      mode = "o",
      function()
        require("flash").remote()
      end,
      desc = "flash: remote",
    },
    {
      "R",
      mode = { "o", "x" },
      function()
        require("flash").treesitter_search()
      end,
      desc = "flash: treesitter search",
    },
    {
      "<c-s>",
      mode = "c",
      function()
        require("flash").toggle()
      end,
      desc = "flash: toggle search",
    },
    -- Treesitter incremental selection
    {
      "<c-space>",
      mode = { "n", "o", "x" },
      function()
        require("flash").treesitter({
          label = {
            style = "overlay",
            rainbow = { enabled = false },
          },
          highlight = {
            backdrop = false,
            matches = false,
          },
          search = {
            incremental = false,
          },
          actions = {
            ["<c-space>"] = "next",
            ["<BS>"] = "prev",
          },
        })
      end,
      desc = "flash: treesitter incremental selection",
    },
  },
  opts = {
    jump = {
      autojump = false,
    },
    label = {
      uppercase = false,
      min_pattern_length = 2,
      rainbow = {
        enabled = false,
        shade = 5,
      },
    },
    modes = {
      char = {
        enabled = false,
      },
      search = {
        enabled = true,
      },
    },
    search = {
      mode = "exact",
      exclude = dot.filetype.get_no_flash_filetypes(),
    },
  },
}
