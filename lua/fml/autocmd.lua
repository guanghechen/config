local fs = require("eve.lib.fs")
local path = require("eve.lib.path")
local augroup = require("eve.builtin.nvim").augroup
local status = require("eve.builtin.status")
local widgets = require("eve.builtin.widgets")
local state = require("eve.state")
local refresh_state = require("fml.fn.refresh_state")

refresh_state()

vim.api.nvim_create_autocmd("VimEnter", {
  group = augroup("on_vim_enter"),
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
          pcall(function()
            vim.bo[bufnr].swapfile = false
            vim.api.nvim_buf_set_name(bufnr, new_filepath)
            eve.buf.refresh(bufnr)
          end)
        end
      end
    end

    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("TabEnter", {
  group = augroup("on_tab_enter"),
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    state.state.tab_history:push(tabnr)
    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("TabClosed", {
  group = augroup("on_tab_closed"),
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

vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
  group = augroup("on_win_or_buf_enter"),
  callback = function(arg)
    local bufnr = arg.buf ---@type integer
    local winnr = vim.api.nvim_get_current_win() ---@type integer

    eve.win.on_buf_enter(winnr, bufnr)
    eve.tab.on_buf_enter(winnr, bufnr)

    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("WinClosed", {
  group = augroup("on_win_closed"),
  callback = function()
    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
  group = augroup("on_mode_changed"),
  callback = function()
    status.statusline_dirtier:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = augroup("on_diagnostic_changed"),
  callback = function()
    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
  group = augroup("on_content_changed"),
  callback = function()
    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("CursorHold", {
  group = augroup("on_cursor_hold"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    status.winline_dirty_nr:next(winnr)
    status.statusline_dirtier:mark_dirty()
  end,
})

local lsp_progress_spinners = { "", "", "", "󰪞", "󰪟", "󰪠", "󰪢", "󰪣", "󰪤", "󰪥" }
vim.api.nvim_create_autocmd("LspProgress", {
  group = augroup("on_lsp_progress"),
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
    status.statusline_dirtier:mark_dirty()
  end,
})

---! Auto resize splits when window got resized.
vim.api.nvim_create_autocmd("VimResized", {
  group = augroup("on_vim_resized"),
  callback = function()
    local current_tab = vim.fn.tabpagenr() ---@type integer
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
    widgets.resize()

    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()

    if vim.env.TMUX then
      local tmux = require("eve.lib.tmux")
      local is_tmux_pane_zoomed = tmux.is_tmux_pane_zoomed() ---@type boolean
      status.tmux_zen_mode:next(is_tmux_pane_zoomed)
    end
  end,
})

vim.api.nvim_create_autocmd("WinResized", {
  group = augroup("on_win_resized"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    status.winline_dirty_nr:next(winnr)
  end,
})
