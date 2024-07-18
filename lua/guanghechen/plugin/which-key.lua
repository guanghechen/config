return {
  "folke/which-key.nvim",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
  opts_extend = { "spec" },
  opts = {
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
        { "<leader>m", group = "marks/bookmarks" },
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
