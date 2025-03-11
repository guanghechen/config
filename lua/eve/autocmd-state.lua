local fn = require("eve.builtin.fn")
local fs = require("eve.builtin.fs")
local path = require("eve.builtin.path")
local tmux = require("eve.builtin.tmux")
local editor = require("eve.module.editor")

local state = require("eve.state")

state.refresh()

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = fn.augroup("state_on_vim_leave_pre"),
  once = true,
  callback = function()
    state.dispose()
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = fn.augroup("state_on_vim_enter"),
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
        local new_filepath = state.buf.pick_filepath(filepath, existed_filepaths) ---@type string|nil
        if new_filepath ~= nil then
          pcall(function()
            vim.bo[bufnr].swapfile = false
            vim.api.nvim_buf_set_name(bufnr, new_filepath)
            state.buf.refresh(bufnr)
          end)
        end
      end
    end

    state.status.dirtier_statusline:mark_dirty()
    state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("TabEnter", {
  group = fn.augroup("state_on_tab_enter"),
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    state.tab.tab_history:push(tabnr)
    state.status.dirtier_statusline:mark_dirty()
    state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("TabClosed", {
  group = fn.augroup("state_on_tab_closed"),
  callback = function()
    local tabnr_last = state.tab.tab_history:present() ---@type integer|nil
    vim.schedule(function()
      if tabnr_last ~= nil and vim.api.nvim_tabpage_is_valid(tabnr_last) then
        vim.api.nvim_set_current_tabpage(tabnr_last)
      end
      state.refresh()
    end)
    state.status.dirtier_statusline:mark_dirty()
    state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
  group = fn.augroup("state_on_win_or_buf_enter"),
  callback = function(arg)
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    local bufnr = arg.buf ---@type integer

    state.win.on_buf_enter(winnr, bufnr)
    state.tab.on_buf_enter(tabnr, winnr, bufnr)

    state.status.dirty_winline_nr:next(winnr)
    state.status.dirtier_statusline:mark_dirty()
    state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("WinClosed", {
  group = fn.augroup("state_on_win_closed"),
  callback = function(args)
    local winnr = type(args) == "table" and args.file or nil ---@type integer|nil
    if type(winnr) == "number" then
      state.status.maximized_winnrs[winnr] = nil
    end

    state.status.dirtier_statusline:mark_dirty()
    state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
  group = fn.augroup("state_on_mode_changed"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    state.status.dirty_winline_nr:next(winnr)
    state.status.dirtier_statusline:mark_dirty()
    state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = fn.augroup("state_on_diagnostic_changed"),
  callback = function()
    state.status.dirtier_statusline:mark_dirty()
    state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
  group = fn.augroup("state_on_content_changed"),
  callback = function()
    state.status.dirtier_statusline:mark_dirty()
    state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("CursorHold", {
  group = fn.augroup("state_on_cursor_hold"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    state.status.dirty_winline_nr:next(winnr)
    state.status.dirtier_statusline:mark_dirty()
  end,
})

local lsp_progress_spinners = { "", "", "", "󰪞", "󰪟", "󰪠", "󰪢", "󰪣", "󰪤", "󰪥" }
vim.api.nvim_create_autocmd("LspProgress", {
  group = fn.augroup("state_on_lsp_progress"),
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
    state.status.lsp_msg:next(lsp_msg)

    if data.kind == "end" then
      state.status.suppress_warning:next(false)
    end
  end,
})

vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
  callback = function()
    state.status.dirtier_statusline:mark_dirty()
  end,
})

---! Auto resize splits when window got resized.
vim.api.nvim_create_autocmd("VimResized", {
  group = fn.augroup("state_on_vim_resized"),
  callback = function()
    ---Switch to a fixed window to avoid the current floating window being taken affect by `wincmd =`
    local tabnr_cur = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr_cur = vim.api.nvim_tabpage_get_win(tabnr_cur) ---@type integer
    local winnr_fixed = editor.find_winnr_fixed() or winnr_cur ---@type integer

    if winnr_cur ~= winnr_fixed then
      vim.api.nvim_tabpage_set_win(tabnr_cur, winnr_fixed)
    end
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. tabnr_cur)

    vim.api.nvim_tabpage_set_win(tabnr_cur, winnr_cur)
    vim.schedule(function()
      state.widget.resize()

      state.status.dirtier_statusline:mark_dirty()
      state.status.dirtier_tabline:mark_dirty()

      if vim.env.TMUX then
        local is_tmux_pane_zoomed = tmux.is_tmux_pane_zoomed() ---@type boolean
        state.status.tmux_zen_mode:next(is_tmux_pane_zoomed)
      end
    end)
  end,
})

vim.api.nvim_create_autocmd("WinResized", {
  group = fn.augroup("state_on_win_resized"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    state.status.dirty_winline_nr:next(winnr)
  end,
})
