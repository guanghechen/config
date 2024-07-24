local lsp = require("fml.api.lsp")

vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold" }, {
  callback = function()
    vim.schedule(function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      lsp.locate_symbols(winnr)
    end)
  end,
})
