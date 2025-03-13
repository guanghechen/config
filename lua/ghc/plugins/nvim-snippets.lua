local path = require("eve.std.path")

return {
  name = "nvim-snippets",
  opts = {
    create_cmp_source = true,
    friendly_snippets = true,
    global_snippets = { "all", "global" },
    search_paths = {
      path.locate_config_filepath("snippets"),
    },
  },
  dependencies = {
    "friendly-snippets",
  },
}
