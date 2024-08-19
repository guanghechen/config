-- better vim.ui input/select
return {
  url = "https://github.com/guanghechen/mirror.git",
  branch = "nvim@dressing.nvim",
  name = "dressing.nvim",
  main = "dressing",
  event = { "VeryLazy" },
  opts = {
    input = {
      insert_only = false,
      start_in_insert = false,
    },
  },
  init = function()
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.ui.select = function(...)
      require("lazy").load({ plugins = { "dressing.nvim" } })
      return vim.ui.select(...)
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.ui.input = function(...)
      require("lazy").load({ plugins = { "dressing.nvim" } })
      return vim.ui.input(...)
    end
  end,
}
