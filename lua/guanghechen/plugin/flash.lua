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
      desc = "Flash",
    },
    {
      "S",
      mode = { "n", "o", "x" },
      function()
        require("flash").treesitter()
      end,
      desc = "Flash Treesitter",
    },
    {
      "r",
      mode = "o",
      function()
        require("flash").remote()
      end,
      desc = "Remote Flash",
    },
    {
      "R",
      mode = { "o", "x" },
      function()
        require("flash").treesitter_search()
      end,
      desc = "Treesitter Search",
    },
    {
      "<C-s>",
      mode = { "c" },
      function()
        require("flash").toggle()
      end,
      desc = "Toggle Flash Search",
    },
  },
  opts = {
    jump = {
      autojump = false,
    },
    label = {
      uppercase = false,
      rainbow = {
        enabled = false,
        shade = 5,
      }
    },
    modes = {
      char = {
        enabled = false,
      }
    },
    search = {
      mode = "exact",
      exclude = {
        "cmp_menu",
        "noice",
        "notify",
        "flash_prompt",
      }
    }
  },
}
