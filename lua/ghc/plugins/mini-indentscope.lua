---@see https://github.com/nvim-mini/mini.ai/tree/0308f949f31769e509696af5d5f91cebb2159c69

-- Active indent guide and indent text objects. When you're browsing
-- code, this highlights the current level of indentation, and animates
-- the highlighting.
return {
  name = "mini.indentscope",
  event = "VeryLazy",
  opts = {
    symbol = "╎",
    options = {
      border = "both",
      indent_at_cursor = true,
      n_lines = 512,
      try_as_border = true,
    },
  },
}
