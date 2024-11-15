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
      filetypes = {
        eve.constants.FT_NEOTREE,
        eve.constants.FT_SEARCH_INPUT,
        eve.constants.FT_SEARCH_INPUT,
        eve.constants.FT_SEARCH_MAIN,
        eve.constants.FT_SEARCH_PREVIEW,
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
    hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
      local theme = eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
      local mode = eve.context.state.theme.mode:snapshot() ---@type t.eve.e.ThemeMode
      local transparency = eve.context.state.theme.transparency:snapshot() ---@type boolean

      fml.ux.theme.load_integration({
        theme = theme,
        mode = mode,
        transparency = transparency,
        integration = "plugin",
      })
    end)

    require("ibl").setup(opts)
  end,
}
