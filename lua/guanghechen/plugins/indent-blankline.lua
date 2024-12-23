local ft = require("eve.lib.filetype")

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
      enabled = false, --- Since we used the mini.indentscope plugin
      show_start = false,
      show_end = false,
      highlight = "IblScopeChar",
    },
    exclude = {
      filetypes = ft.get_no_ibl_filetypes(),
    },
  },
  config = function(_, opts)
    local hooks = require("ibl.hooks")
    hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
    require("ibl").setup(opts)
  end,
}
