-- indent guides for Neovim
return {
  name = "indent-blankline.nvim",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  opts = {
    indent = {
      char = "│",
      tab_char = "┃",
      highlight = {
        "@ibl.scope.underline.0",
        "@ibl.scope.underline.1",
        "@ibl.scope.underline.2",
        "@ibl.scope.underline.3",
        "@ibl.scope.underline.4",
        "@ibl.scope.underline.5",
        "@ibl.scope.underline.6",
        "@ibl.scope.underline.7",
      },
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
      filetypes = eve.filetype.get_no_ibl_filetypes(),
    },
  },
  config = function(_, opts)
    local hooks = require("ibl.hooks")
    -- hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
    hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
      eve.state.theme.apply_integration({
        theme = eve.state.theme.theme:snapshot(),
        transparency = eve.state.theme.transparency:snapshot(),
        integration = "plugin",
      })
    end)
    require("ibl").setup(opts)
  end,
}
