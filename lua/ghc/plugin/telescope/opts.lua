local opts = {
  defaults = {
    border = true,
    color_devicons = true,
    dynamic_preview_title = true,
    file_ignore_patterns = { ".git/", ".cache", "build/", "%.class", "%.pdf", "%.mkv", "%.mp4", "%.zip" },
    initial_mode = "insert",
    layout_config = {
      horizontal = {
        width = 0.85,
        height = 0.92,
        prompt_position = "top",
      },
      vertical = {
        width = 0.85,
        height = 0.92,
        mirror = false,
      },
      preview_cutoff = 120,
    },
    layout_strategy = "horizontal",
    -- path_display = { "absolute" },
    results_title = false,
    scroll_strategy = "cycle",
    selection_strategy = "reset",
    sorting_strategy = "ascending",
    use_less = false,
    wrap_results = false,
  },
  extensions = {
    file_browser = {},
    frecency = {
      use_sqlite = false,
      show_scores = true,
      show_unindexed = true,
      ignore_patterns = { "*.git/*", "*/tmp/*", "*node_modules/*" },
    },
    fzf = {
      fuzzy = false,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },
    live_grep_args = {
      auto_quoting = true, -- enable/disable auto-quoting
    },
  },
}

return opts
