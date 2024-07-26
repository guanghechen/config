local lsp = require("fml.api.lsp")
local state = require("fml.api.state")

vim.api.nvim_create_autocmd({ "BufAdd", "BufEnter" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local win = state.wins[winnr] ---@type fml.types.api.state.IWinItem|nil
    if win ~= nil and not state.is_floating_win(winnr) then
      win.lsp_symbols = {} ---@type fml.types.api.state.ILspSymbol[]
      vim.defer_fn(function()
        state.winline_dirty_nr:next(winnr)
      end, 20)
    end
  end,
})

vim.api.nvim_create_autocmd({ "CursorHold" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    vim.schedule(function()
      lsp.locate_symbols(winnr, true)
    end)
  end,
})
