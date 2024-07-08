return {
  "folke/which-key.nvim",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  keys = { "<leader>", '"', "'", "`", "c", "v", "g" },
  opts = {
    defaults = {
      mode = { "n", "v" },
      ["g"] = { name = "+goto" },
      ["gs"] = { name = "+surround" },
      ["z"] = { name = "+fold" },
      ["]"] = { name = "+next" },
      ["["] = { name = "+prev" },
      ["<leader>b"] = { name = "+buffer" },
      ["<leader>c"] = { name = "+code" },
      ["<leader>d"] = { name = "+debug" },
      ["<leader>e"] = { name = "+explorer" },
      ["<leader>f"] = { name = "+find/file" },
      ["<leader>g"] = { name = "+find/git" },
      ["<leader>m"] = { name = "+marks/bookmarks" },
      ["<leader>q"] = { name = "+quit/session" },
      ["<leader>s"] = { name = "+search/replace" },
      ["<leader>t"] = { name = "+tab/terminal" },
      ["<leader>u"] = { name = "+ui" },
      ["<leader>w"] = { name = "+window" },
      ["<leader>x"] = { name = "+diagnostics/quickfix" },
    },
  },
  config = function(_, opts)
    vim.o.timeout = true
    vim.o.timeoutlen = 700

    require("which-key").setup(opts)
    require("which-key").register(opts.defaults)
  end,
}
