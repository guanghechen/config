---@see https://github.com/folke/flash.nvim

-- Flash enhances the built-in search functionality by showing labels
-- at the end of each match, letting you quickly jump to a specific location.
return {
  name = "flash.nvim",
  keys = {
    {
      lhs = "/",
      mode = { "n", "x", "o" },
      desc = "flash: search",
    },
    {
      lhs = "?",
      mode = { "n", "x", "o" },
      desc = "flash: search backward",
    },
    {
      lhs = "s",
      mode = { "n", "x", "o" },
      rhs = function()
        require("flash").jump()
      end,
      desc = "flash: jump",
    },
    {
      lhs = "S",
      mode = { "n", "o", "x" },
      rhs = function()
        require("flash").treesitter({
          label = { style = "overlay" },
          highlight = { backdrop = true },
        })
      end,
      desc = "flash: treesitter",
    },
    {
      lhs = "r",
      mode = "o",
      rhs = function()
        require("flash").remote()
      end,
      desc = "flash: remote",
    },
    {
      lhs = "R",
      mode = { "o", "x" },
      rhs = function()
        require("flash").treesitter_search()
      end,
      desc = "flash: treesitter search",
    },
    {
      lhs = "<c-s>",
      mode = "c",
      rhs = function()
        require("flash").toggle()
      end,
      desc = "flash: toggle search",
    },
    -- Treesitter incremental selection
    {
      lhs = "<c-space>",
      mode = { "n", "o", "x" },
      rhs = function()
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
      exclude = stl.filetype.get_no_flash_filetypes(),
    },
  },
}
