local fs = require("eve.lib.fs")
local path = require("eve.lib.path")
local tmux = require("eve.lib.tmux")
local status = require("eve.builtin.status")
local state = require("eve.state")
local refresh_state = require("fml.fn.refresh_state")

refresh_state()

---! Watch the zen mode change on tmux.
if vim.env.TMUX then
  vim.api.nvim_create_autocmd({ "VimResized" }, {
    callback = function()
      local is_tmux_pane_zoomed = tmux.is_tmux_pane_zoomed() ---@type boolean
      status.tmux_zen_mode:next(is_tmux_pane_zoomed)
      status.statusline_dirtier:mark_dirty()
      status.tabline_dirtier:mark_dirty()
    end,
  })
end

vim.api.nvim_create_autocmd({ "WinResized" }, {
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      vim.schedule(function()
        status.winline_dirty_nr:next(winnr)
      end)
    end
  end,
})

vim.api.nvim_create_autocmd({ "ModeChanged" }, {
  callback = function()
    status.statusline_dirtier:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
  callback = function(arg)
    local bufnr = arg.buf ---@type integer
    eve.win.on_buf_enter(bufnr)
    eve.tab.on_buf_enter(bufnr)

    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local meta_win = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
    if meta_win ~= nil then
      status.winline_dirty_nr:next(winnr)

      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local meta_tab = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      if meta_tab ~= nil then
        meta_tab.winnr_listed = winnr
      end
    end

    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd({ "TabEnter" }, {
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    state.state.tab_history:push(tabnr)
    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
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
    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd({ "WinClosed" }, {
  callback = function()
    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
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

    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd({ "CursorHold" }, {
  callback = function()
    local meta_tab = eve.tab.get_current() ---@type eve.t.state.state.tab.IMeta|nil
    local winnr = meta_tab and meta_tab.winnr_listed or 0 ---@type integer
    if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
      vim.schedule(function()
        eve.win.locate_symbols(winnr)
      end)
    end
    status.statusline_dirtier:mark_dirty()
  end,
})

local lsp_progress_spinners = { "", "", "", "󰪞", "󰪟", "󰪠", "󰪢", "󰪣", "󰪤", "󰪥" }
vim.api.nvim_create_autocmd("LspProgress", {
  callback = function(args)
    local data = args.data.params.value
    local progress = ""

    if data.percentage then
      local idx = math.max(1, math.floor(data.percentage / 10))
      local icon = lsp_progress_spinners[idx]
      progress = icon .. " " .. data.percentage .. "%% "
    end

    local str = progress .. (data.message or "") .. " " .. (data.title or "")
    local lsp_msg = data.kind == "end" and "" or str ---@type string
    status.lsp_msg:next(lsp_msg)
  end,
})
