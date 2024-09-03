return {
  name = "which-key.nvim",
  event = { "VeryLazy" },
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  opts_extend = { "spec" },
  opts = {
    disable = {
      ft = {
        eve.constants.FT_NEOTREE,
        eve.constants.FT_SEARCH_INPUT,
        eve.constants.FT_SEARCH_MAIN,
        eve.constants.FT_SEARCH_PREVIEW,
        eve.constants.FT_TERM,
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
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "debug" },
        { "<leader>e", group = "explorer" },
        { "<leader>f", group = "find/file" },
        { "<leader>g", group = "find/git" },
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
