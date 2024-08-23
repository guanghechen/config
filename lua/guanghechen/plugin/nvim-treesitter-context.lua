---! https://github.com/nvim-treesitter/nvim-treesitter-context
return {
  name = "nvim-treesitter-context",
  enabled = true,
  event = { "VeryLazy" },
  opts = {
    enable = true,
    line_numbers = true,
    max_lines = 7,
    min_window_height = 30,
    mode = "cursor",
    multiline_threshold = 20,
    separator = nil,
    trim_scope = "outer",
    zindex = 30,
  },
}
