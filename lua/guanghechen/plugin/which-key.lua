return {
  "folke/which-key.nvim",
  event = { "VeryLazy" },
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  opts_extend = { "spec" },
  opts = {
    disable = {
      ft = {
        fml.constant.FT_TERM,
        fml.constant.FT_SELECT_INPUT,
        fml.constant.FT_SELECT_MAIN,
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
