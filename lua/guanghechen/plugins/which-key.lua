return {
  name = "which-key.nvim",
  event = { "VeryLazy" },
  opts_extend = { "spec" },
  opts = {
    disable = {
      ft = {
        eve.constants.FT_TERM,
        eve.constants.FT_WINSEP,
      },
    },
    spec = {
      {
        mode = { "n", "v" },
        { "g", group = "goto" },
        { "gs", group = "surround" },
        { "z", group = "fold" },
        { "]", group = "next" },
        { "[", group = "prev" },
        { "<leader>a", group = "ai" },
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "debug" },
        { "<leader>e", group = "explorer" },
        { "<leader>f", group = "find/file" },
        { "<leader>g", group = "git" },
        { "<leader>gh", group = "git hunk" },
        { "<leader>q", group = "quit/session" },
        { "<leader>s", group = "search/replace" },
        { "<leader>t", group = "tab/terminal" },
        { "<leader>u", group = "ui" },
        { "<leader>w", group = "window" },
        { "<leader>x", group = "diagnostics/quickfix" },
      },
    },
  },
}
