-- Flash enhances the built-in search functionality by showing labels
-- at the end of each match, letting you quickly jump to a specific location.
return {
  name = "flash.nvim",
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
        require("flash").treesitter()
      end,
      desc = "flash: treesitter",
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
      },
    },
    modes = {
      char = {
        enabled = false,
        multi_line = false,
        keys = { "f", "F", "t", "T", ",", ";" },
      },
    },
    search = {
      mode = "exact",
      exclude = eve.c.filetype.get_no_flash_filetypes(),
    },
  },
}
