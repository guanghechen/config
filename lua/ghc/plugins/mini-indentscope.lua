-- Active indent guide and indent text objects. When you're browsing
-- code, this highlights the current level of indentation, and animates
-- the highlighting.
return {
  name = "mini.indentscope",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  opts = {
    symbol = "╎",
    options = {
      try_as_border = true,
    },
  },
}
