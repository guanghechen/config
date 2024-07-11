local winline = require("ghc.ui.winline")

vim.api.nvim_create_autocmd({ "WinResized", "BufWinEnter", "CursorHold", "InsertLeave" }, {
  group = fml.fn.augroup("winline_autorefresh"),
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      winline.update(winnr)
    end
  end,
})
