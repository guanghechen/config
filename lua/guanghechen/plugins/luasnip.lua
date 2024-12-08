local env = require("eve.lib.env")

return {
  name = "luasnip.nvim",
  build = not env.IS_WIN and "make install_jsregexp" or nil,
  opts = {
    history = true,
    delete_check_events = "TextChanged",
  },
  dependencies = {
    {
      "friendly-snippets",
      config = function()
        require("luasnip.loaders.from_vscode").lazy_load()
      end,
    },
  },
}
