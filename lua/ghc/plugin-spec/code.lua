return {
  -- Change comment mappings
  -- https://www.lazyvim.org/configuration/recipes#change-comment-mappings
  {
    "echasnovski/mini.comment",
    keys = { "gc", "gcc" },
    opts = {
      mappings = {
        comment = "gc",
        comment_line = "gcc",
        comment_visual = "gc",
        textobject = "gcc",
      },
    },
  },

  {
    -- Change surround mappings
    -- https://www.lazyvim.org/configuration/recipes#change-surround-mappings
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
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    },
  },
}
