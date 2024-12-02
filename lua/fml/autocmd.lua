local fs = require("eve.lib.fs")
local path = require("eve.lib.path")
local state = require("eve.state")
local locate_symbols = require("fml.fn.locate_symbols")
local refresh_state = require("fml.fn.refresh_state")

refresh_state()

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  callback = function(arg)
    local bufnr = arg.buf ---@type integer
    eve.win.on_buf_enter(bufnr)
    eve.tab.on_buf_enter(bufnr)

    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local meta = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
    if meta ~= nil then
      meta.lsp_symbols = {} ---@type eve.t.state.state.lsp.ISymbol[]
      vim.defer_fn(function()
        state.state.status.winline_dirty_nr:next(winnr)
      end, 20)
    end
  end,
})

vim.api.nvim_create_autocmd({ "TabEnter" }, {
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    state.state.tab_history:push(tabnr)
  end,
})

vim.api.nvim_create_autocmd({ "TabClosed" }, {
  callback = function()
    local tabnr_last = state.state.tab_history:present() ---@type integer|nil
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
    local cwd = path.cwd() ---@type string
    local existed_filepaths = {} ---@type table<string, boolean>
    local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local filepath = path.resolve(cwd, filename) ---@type string
      existed_filepaths[filepath] = true
    end

    for _, bufnr in ipairs(bufnrs) do
      local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local filepath = path.resolve(cwd, filename) ---@type string
      if fs.is_file_or_dir(filepath) == "directory" then
        local new_filepath = eve.buf.pick_filepath(filepath, existed_filepaths) ---@type string|nil
        if new_filepath ~= nil then
          vim.api.nvim_buf_set_name(bufnr, new_filepath)
          eve.buf.refresh(bufnr)
        end
      end
    end
  end,
})

vim.api.nvim_create_autocmd({ "CursorHold" }, {
  callback = function()
    local winnr = eve.locations.get_current_winnr() ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      vim.schedule(function()
        locate_symbols(winnr, true)
      end)
    end
  end,
})
