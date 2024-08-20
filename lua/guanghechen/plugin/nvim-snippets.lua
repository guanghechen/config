return {
  name = "nvim-snippets",
  opts = {
    create_cmp_source = true,
    friendly_snippets = true,
    global_snippets = { "all", "global" },
    search_paths = {
      fml.path.locate_config_filepath("_editor/snippets"),
    },
  },
  dependencies = {
    "friendly-snippets"
  },
}
