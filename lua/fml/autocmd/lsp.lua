local lsp = require("fml.api.lsp")
local throttle_leading = require("fml.fn.throttle_leading")

local refresh_lsp_symbols = throttle_leading(function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  lsp.locate_symbols(winnr)
end, 100).throttled

vim.api.nvim_create_autocmd({ "WinResized", "BufWinEnter", "CursorHold", "InsertLeave" }, {
  callback = function()
    refresh_lsp_symbols()
  end,
})
