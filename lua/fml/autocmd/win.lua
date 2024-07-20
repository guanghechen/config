local state = require("fml.api.state")

vim.api.nvim_create_autocmd({ "VimEnter", "WinEnter" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if state.validate_win(winnr) then
      state.win_history:push(winnr)

      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local tab = state.tabs[tabnr]
      if tab ~= nil then
        tab.winnr_cur:next(winnr)
      end
    end
  end,
})
