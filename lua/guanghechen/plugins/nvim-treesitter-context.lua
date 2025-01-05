---! https://github.com/nvim-treesitter/nvim-treesitter-context
return {
  name = "nvim-treesitter-context",
  enabled = false,
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  opts = {
    enable = true,
    line_numbers = true,
    max_lines = 3,
    min_window_height = 30,
    mode = "cursor",
    multiline_threshold = 20,
    separator = nil,
    trim_scope = "outer",
    zindex = 30,
  },
}
