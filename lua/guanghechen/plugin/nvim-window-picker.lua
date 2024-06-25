return {
  "guanghechen/mirror",
  branch = "nvim@nvim-window-picker",
  name = "nvim-window-picker",
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
