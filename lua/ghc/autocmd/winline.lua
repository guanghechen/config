local winline = require("ghc.ui.winline")

local augroups = {
  refresh_winline = fml.util.augroup("refresh_winline"),
}

vim.api.nvim_create_autocmd({ "WinResized" }, {
  group = augroups.refresh_winline,
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      vim.schedule(function()
        winline.update(winnr, true)
      end)
    end
  end,
})

vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave", "BufWinEnter" }, {
  group = augroups.refresh_winline,
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    vim.schedule(function()
      winline.update(winnr, true)
    end)
  end,
})
