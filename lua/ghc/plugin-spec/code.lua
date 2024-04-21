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
    keys = { "gsa", "gsd", "gsf", "gsF", "gsh", "gsr", "gsn" },
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

  -- Active indent guide and indent text objects. When you're browsing
  -- code, this highlights the current level of indentation, and animates
  -- the highlighting.
  {
    "echasnovski/mini.indentscope",
    version = false, -- wait till new 0.7.0 release to put it back on semver
    opts = {
      -- symbol = "▏",
      symbol = "│",
      options = { try_as_border = true },
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "help",
          "alpha",
          "dashboard",
          "neo-tree",
          "Trouble",
          "trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "lazyterm",
        },
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
  },
}
