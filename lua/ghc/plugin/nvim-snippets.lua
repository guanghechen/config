local guanghechen = require("guanghechen")

return {
  "garymjr/nvim-snippets",
  opts = {
    friendly_snippets = true,
    global_snippets = { "all", "global" },
    search_paths = {
      guanghechen.util.path.locate_config_filepath("_editor/snippets"),
    },
  },
  dependencies = { "rafamadriz/friendly-snippets" },
}
