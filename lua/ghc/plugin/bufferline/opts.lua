local function numbers(opts)
  return string.format("%s", opts.raise(opts.ordinal))
end

return {
  options = {
    always_show_bufferline = true,
    enforce_regular_tabs = false,
    max_name_length = 20,
    max_prefix_length = 13,
    numbers = numbers,
    persist_buffer_sort = true,
    separator_style = "thin",
    show_buffer_icons = true,
    show_buffer_close_icons = true,
    show_close_icon = true,
    show_tab_indicators = true,
    tab_size = 20,
  },
  -- Change bufferline's highlights here! See `:h bufferline-highlights` for detailed explanation.
  -- Note: If you use catppuccin then modify the colors below!
  highlights = {},
}
