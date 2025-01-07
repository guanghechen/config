local ft = require("eve.constant.filetype")

-- indent guides for Neovim
return {
  name = "indent-blankline.nvim",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  opts = {
    indent = {
      char = "│",
      tab_char = "┃",
      highlight = "IblChar",
    },
    whitespace = {
      highlight = { "Whitespace", "NonText" },
      remove_blankline_trail = false,
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
}
