local state = require("fml.api.state")

vim.api.nvim_create_autocmd({ "VimEnter", "WinNew", "WinEnter" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if state.is_floating_win(winnr) then
      return
    end

    state.win_history:push(winnr)

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local tab = state.tabs[tabnr] ---@type fml.types.api.state.ITabItem|nil
    if tab ~= nil then
      tab.winnr_cur:next(winnr)
    end

    vim.schedule(function()
      state.refresh_win(winnr)
    end)
  end,
})

vim.api.nvim_create_autocmd({ "WinClosed" }, {
  callback = function()
    state.schedule_refresh_wins()
  end,
})
