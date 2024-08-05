local state = require("fml.api.state")

vim.api.nvim_create_autocmd({ "TabEnter" }, {
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    state.tab_history:push(tabnr)

    vim.schedule(function()
      state.refresh_tab(tabnr)
      state.refresh_tabpage_wins(tabnr)
    end)
  end,
})

vim.api.nvim_create_autocmd({ "TabClosed" }, {
  callback = function()
    state.schedule_refresh_all()

    local tabnr_last = state.tab_history:present() ---@type integer|nil
    vim.schedule(function()
      if tabnr_last ~= nil and vim.api.nvim_tabpage_is_valid(tabnr_last) then
        vim.api.nvim_set_current_tabpage(tabnr_last)
      end
    end)
  end,
})
