return {
  {
    "folke/which-key.nvim",
    opts = {
      defaults = {
        ["<leader>b"] = { name = "+buffer" },
        ["<leader>c"] = { name = "+code" },
        ["<leader>f"] = { name = "+find/file" },
        ["<leader>g"] = { name = "+find/git" },
        ["<leader>q"] = { name = "+quit/session" },
        ["<leader>s"] = { name = "+search" },
        ["<leader>t"] = { name = "+terminal" },
        ["<leader>u"] = { name = "+ui" },
        ["<leader>w"] = { name = "+window" },
        ["<leader>x"] = { name = "+diagnostics/quickfix" },
      },
    },
  }
}