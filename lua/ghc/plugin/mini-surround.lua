-- https://www.lazyvim.org/configuration/recipes#change-surround-mappings
-- Change surround mappings
return {
  "echasnovski/mini.surround",
  keys = {
    { "gsa", mode = { "n", "v" } },
    "gsd",
    "gsf",
    "gsF",
    "gsh",
    "gsr",
    "gsn",
  },
  opts = {
    mappings = {
      add = "gsa", -- Add surrounding in Normal and Visual modes
      delete = "gsd", -- Delete surrounding
      find = "gsf", -- Find surrounding (to the right)
      find_left = "gsF", -- Find surrounding (to the left)
      highlight = "gsh", -- Highlight surrounding
      replace = "gsr", -- Replace surrounding
      update_n_lines = "gsn", -- Update `n_lines`
    },
    n_lines = 300,
  },
}
