-- better vim.ui input/select
return {
  name = "dressing.nvim",
  event = { "VeryLazy" },
  init = function()
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.ui.input = function(...)
      require("lazy").load({ plugins = { "dressing.nvim" } })
      return vim.ui.input(...)
    end
  end,
  opts = {
    input = {
      enabled = true,
      insert_only = false,
      start_in_insert = false,
    },
    select = {
      enabled = false,
    },
  },
}
