local state = require("fml.api.state")

vim.api.nvim_create_autocmd({ "BufAdd", "BufWinEnter" }, {
  callback = function(args)
    local bufnr = args.buf
    if type(bufnr) ~= "number" then
      return
    end

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    vim.schedule(function()
      state.refresh_buf(bufnr)
      state.refresh_tab(tabnr)
    end)
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local win = state.wins[winnr]
    if win ~= nil then
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      win.filepath_history:push(filepath)
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete" }, {
  callback = function(args)
    local bufnr = args.buf
    if type(bufnr) ~= "number" then
      return
    end

    state.bufs[bufnr] = nil
    for _, tab in pairs(state.tabs) do
      if tab.bufnr_set[bufnr] then
        tab.bufnr_set[bufnr] = nil
        eve.array.filter_inline(tab.bufnrs, function(nr)
          return nr ~= bufnr
        end)
      end
    end
  end,
})

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
