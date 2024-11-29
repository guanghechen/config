local refresh_state = require("fml.fn.refresh_state")
local api_buf = require("fml.api.buf")
local api_tab = require("fml.api.tab")
local api_win = require("fml.api.win")

refresh_state()

vim.api.nvim_create_autocmd({ "BufAdd", "BufWinEnter" }, {
  callback = function(args)
    local bufnr = args.buf
    if type(bufnr) == "number" then
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      vim.schedule(function()
        api_buf.refresh(bufnr)
        api_tab.refresh(tabnr)
      end)
    end
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
    if type(bufnr) == "number" then
      eve.context.state.bufs[bufnr] = nil
      for _, tab in pairs(eve.context.state.tabs) do
        if tab.bufnr_set[bufnr] then
          tab.bufnr_set[bufnr] = nil
          eve.array.filter_inline(tab.bufnrs, function(nr)
            return nr ~= bufnr
          end)
        end
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

vim.api.nvim_create_autocmd({ "VimEnter" }, {
  callback = function()
    local cwd = eve.path.cwd() ---@type string
    local existed_filepaths = {} ---@type table<string, boolean>
    local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local filepath = eve.path.resolve(cwd, filename) ---@type string
      existed_filepaths[filepath] = true
    end

    for _, bufnr in ipairs(bufnrs) do
      local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local filepath = eve.path.resolve(cwd, filename) ---@type string
      if eve.fs.is_file_or_dir(filepath) == "directory" then
        local new_filepath = eve.buf.pick_filepath(filepath, existed_filepaths) ---@type string|nil
        if new_filepath ~= nil then
          vim.api.nvim_buf_set_name(bufnr, new_filepath)
        end
      end
    end
  end,
})

vim.api.nvim_create_autocmd({ "VimEnter", "WinNew", "WinEnter" }, {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if eve.win.is_floating(winnr) then
      return
    end

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local tab = eve.context.state.tabs[tabnr] ---@type eve.t.context.state.tab.IItem|nil
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
    local win = eve.context.state.wins[winnr] ---@type eve.t.context.state.win.IItem|nil
    if win ~= nil and not eve.win.is_floating(winnr) then
      win.lsp_symbols = {} ---@type eve.t.context.state.lsp.ISymbol[]
      vim.defer_fn(function()
        eve.context.state.status.winline_dirty_nr:next(winnr)
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
