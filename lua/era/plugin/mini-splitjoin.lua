---@see https://github.com/nvim-mini/mini.splitjoin

return {
  name = "mini.splitjoin",
  keys = {
    { lhs = "gS", mode = { "n", "x" }, desc = "splitjoin: split" },
    { lhs = "gJ", mode = { "n", "x" }, desc = "splitjoin: join" },
  },
  opts = {
    mappings = {
      toggle = "",
      split = "gS",
      join = "gJ",
    },
  },
}
