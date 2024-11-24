return {
  name = "nvim-window-picker",
  opts = {
    hint = "floating-big-letter",
    show_prompt = false,
    filter_rules = {
      autoselect_one = true,
      include_current_win = false,
      bo = {
        filetype = eve.filetype.get_no_window_picker_focusable_filetypes(),
        buftype = { "terminal", "quickfix" },
      },
    },
  },
}
