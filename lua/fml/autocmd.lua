local refresh_state = require("fml.fn.refresh_state")
local api_buf = require("fml.api.buf")
local api_tab = require("fml.api.tab")
local api_win = require("fml.api.win")

---Rebuild the fml.api.state
refresh_state()

vim.api.nvim_create_autocmd({ "BufAdd", "BufWinEnter" }, {
  callback = function(args)
    local bufnr = args.buf
    if type(bufnr) ~= "number" then
      return
    end

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    vim.schedule(function()
      api_buf.refresh(bufnr)
      api_tab.refresh(tabnr)
    end)
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local win = eve.context.state.wins[winnr]
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

    eve.context.state.bufs[bufnr] = nil
    for _, tab in pairs(eve.context.state.tabs) do
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
    eve.context.state.tab_history:push(tabnr)

    vim.schedule(function()
      api_tab.refresh(tabnr)
      api_win.refresh_tabpage_wins(tabnr)
    end)
  end,
})

vim.api.nvim_create_autocmd({ "TabClosed" }, {
  callback = function()
    local tabnr_last = eve.context.state.tab_history:present() ---@type integer|nil
    vim.schedule(function()
      if tabnr_last ~= nil and vim.api.nvim_tabpage_is_valid(tabnr_last) then
        vim.api.nvim_set_current_tabpage(tabnr_last)
      end
      refresh_state()
    end)
  end,
})

vim.api.nvim_create_autocmd({ "VimEnter", "WinNew", "WinEnter" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if eve.win.is_floating(winnr) then
      return
    end

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local tab = eve.context.state.tabs[tabnr] ---@type t.eve.context.state.tab.IItem|nil
    if tab ~= nil then
      tab.winnr_cur:next(winnr)
    end

    vim.schedule(function()
      api_win.refresh(winnr)
    end)
  end,
})

vim.api.nvim_create_autocmd({ "WinClosed" }, {
  callback = function()
    api_win.schedule_refresh_all()
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local win = eve.context.state.wins[winnr] ---@type t.eve.context.state.win.IItem|nil
    if win ~= nil and not eve.win.is_floating(winnr) then
      win.lsp_symbols = {} ---@type t.eve.context.state.lsp.ISymbol[]
      vim.defer_fn(function()
        eve.context.state.winline_dirty_nr:next(winnr)
      end, 20)
    end
  end,
})

vim.api.nvim_create_autocmd({ "CursorHold" }, {
  callback = function()
    local winnr = eve.locations.get_current_winnr() ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      vim.schedule(function()
        api_win.locate_symbols(winnr, true)
      end)
    end
  end,
})
