-- indent guides for Neovim
return {
  "lukas-reineke/indent-blankline.nvim",
  event = { "BufReadPost" },
  main = "ibl",
  opts = {
    indent = {
      char = "│",
      tab_char = "│",
    },
    scope = {
      show_start = false,
      show_end = false,
    },
    exclude = {
      filetypes = {
        "help",
        "alpha",
        "dashboard",
        "neo-tree",
        "Trouble",
        "trouble",
        "lazy",
        "mason",
        "notify",
        "toggleterm",
        "lazyterm",
        "term",
        "kyokuya-replace",
      },
    },
  },
  config = function(_, opts)
    dofile(vim.g.base46_cache .. "blankline")

    local hooks = require("ibl.hooks")
    hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
    require("ibl").setup(opts)

    dofile(vim.g.base46_cache .. "blankline")
  end,
}