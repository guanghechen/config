-- better vim.ui input/select
return {
  name = "dressing.nvim",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
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
      title_pos = "center",
      win_options = {
        winblend = 10,
        winhighlight = table.concat({
          "FloatTitle:RenamerTitle",
          "FloatBorder:FloatBorder",
          "NormalFloat:NormalFloat",
        }, ","),
      },
      mappings = {
        n = {
          ["<Esc>"] = "Close",
          ["q"] = "Close",
          ["<CR>"] = "Confirm",
          ["<C-k>"] = "HistoryPrev",
          ["<C-j>"] = "HistoryNext",
        },
        i = {
          ["<C-c>"] = "Close",
          ["<CR>"] = "Confirm",
          ["<C-k>"] = "HistoryPrev",
          ["<C-j>"] = "HistoryNext",
        },
      },
    },
    select = {
      enabled = false,
    },
  },
}
