---@see https://github.com/nvim-mini/mini.surround/tree/88c52297ed3e69ecf9f8652837888ecc727a28ee

return {
  name = "mini.surround",
  keys = {
    { lhs = "gsa", mode = { "n", "x" }, desc = "surrounding: add" },
    { lhs = "gsd", desc = "surrounding: delete" },
    { lhs = "gsf", desc = "surrounding: find right" },
    { lhs = "gsF", desc = "surrounding: find left" },
    { lhs = "gsh", desc = "surrounding: highlight" },
    { lhs = "gsr", desc = "surrounding: replace" },
    { lhs = "gsn", desc = "surrounding: update n_lines" },
  },
  opts = {
    n_lines = 50,
    respect_selection_type = true, -- Linewise/blockwise add places surroundings on separate lines
    search_method = "cover_or_next", -- Use covering match, fallback to next if not found
    mappings = {
      add = "gsa", -- Add surrounding in Normal and Visual modes
      delete = "gsd", -- Delete surrounding
      find = "gsf", -- Find surrounding (to the right)
      find_left = "gsF", -- Find surrounding (to the left)
      highlight = "gsh", -- Highlight surrounding
      replace = "gsr", -- Replace surrounding
      update_n_lines = "gsn", -- Update `n_lines`
      suffix_last = "", -- Disable extended mappings for "prev" search (e.g., gsdl, gsrl)
      suffix_next = "", -- Disable extended mappings for "next" search (e.g., gsdn, gsrn)
    },
  },
}
