return {
  "akinsho/bufferline.nvim",
  opts = {
    options = {
      always_show_bufferline = true,
      enforce_regular_tabs = false,
      max_name_length = 20,
      max_prefix_length = 13,
      numbers = function(opts)
        return string.format("%s", opts.raise(opts.ordinal))
      end,
      persist_buffer_sort = true,
      separator_style = "thin",
      show_buffer_icons = true,
      show_buffer_close_icons = true,
      show_close_icon = true,
      show_tab_indicators = true,
      tab_size = 20,
    },
  },
}
