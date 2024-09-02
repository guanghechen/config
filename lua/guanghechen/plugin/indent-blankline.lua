-- indent guides for Neovim
return {
  name = "indent-blankline.nvim",
  event = { "BufReadPost" },
  opts = {
    indent = {
      char = "│",
      tab_char = "│",
      highlight = "IblChar",
    },
    scope = {
      show_start = false,
      show_end = false,
      highlight = "IblScopeChar",
    },
    exclude = {
      filetypes = {
        eve.constants.FT_SEARCH_INPUT,
        eve.constants.FT_SEARCH_INPUT,
        eve.constants.FT_SEARCH_MAIN,
        eve.constants.FT_SEARCH_PREVIEW,
        eve.constants.FT_SELECT_INPUT,
        eve.constants.FT_SELECT_MAIN,
        eve.constants.FT_TERM,
        "help",
        "alpha",
        "dashboard",
        "neo-tree",
        "Trouble",
        "trouble",
        "lazy",
        "mason",
        "notify",
      },
    },
  },
  config = function(_, opts)
    local hooks = require("ibl.hooks")
    hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
    require("ibl").setup(opts)
    ghc.context.client.reload_partial({ integration = "indent-blank-line" })
  end,
}
