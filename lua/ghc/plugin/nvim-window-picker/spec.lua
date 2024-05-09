return {
  "s1n7ax/nvim-window-picker",
  name = "window-picker",
  event = "VeryLazy",
  version = "2.*",
  main = "window-picker",
  opts = {
    hint = "floating-big-letter",
    show_prompt = false,
    filter_rules = {
      autoselect_one = true,
      include_current_win = false,
      bo = {
        filetype = { "neo-tree", "neo-tree-popup", "noice", "notify" },
        buftype = { "terminal", "quickfix" },
      },
    },
  },
}
