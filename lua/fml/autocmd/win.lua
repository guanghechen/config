local state = require("fml.api.state")

vim.api.nvim_create_autocmd({ "WinEnter" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    state.win_history:push(winnr)
  end
})
