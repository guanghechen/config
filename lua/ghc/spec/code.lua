local util = {
  reporter = require("ghc.core.util.reporter"),
}

return {
  -- Change comment mappings
  -- https://www.lazyvim.org/configuration/recipes#change-comment-mappings
  {
    "echasnovski/mini.comment",
    keys = {
      { "gc", mode = { "n", "v" } },
      { "gcc", mode = { "n", "v" } },
    },
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
        add = "gsa", -- Add surrounding in Normal and Visual modes
        delete = "gsd", -- Delete surrounding
        find = "gsf", -- Find surrounding (to the right)
        find_left = "gsF", -- Find surrounding (to the left)
        highlight = "gsh", -- Highlight surrounding
        replace = "gsr", -- Replace surrounding
        update_n_lines = "gsn", -- Update `n_lines`
      },
    },
  },

  -- auto pairs
  {
    "echasnovski/mini.pairs",
    event = "VeryLazy",
    opts = {
      mappings = {
        ["("] = { action = "open", pair = "()", neigh_pattern = "[^\\]." },
        ["["] = { action = "open", pair = "[]", neigh_pattern = "[^\\]." },
        ["{"] = { action = "open", pair = "{}", neigh_pattern = "[^\\]." },
        [")"] = { action = "close", pair = "()", neigh_pattern = "[^\\]." },
        ["]"] = { action = "close", pair = "[]", neigh_pattern = "[^\\]." },
        ["}"] = { action = "close", pair = "{}", neigh_pattern = "[^\\]." },
        ['"'] = { action = "closeopen", pair = '""', neigh_pattern = "[^\\].", register = { cr = false } },
        ["'"] = { action = "closeopen", pair = "''", neigh_pattern = "[^%a\\].", register = { cr = false } },
        ["`"] = { action = "closeopen", pair = "``", neigh_pattern = "[^\\].", register = { cr = false } },
      },
    },
    keys = {
      {
        "<leader>up",
        function()
          vim.g.minipairs_disable = not vim.g.minipairs_disable
          if vim.g.minipairs_disable then
            util.reporter.warn("Disabled auto pairs", { title = "Option" })
          else
            util.reporter.info("Enabled auto pairs", { title = "Option" })
          end
        end,
        desc = "Toggle Auto Pairs",
      },
    },
  },
}
