vim.api.nvim_create_autocmd("VimLeavePre", {
  group = eve.nvim.augroup("state_on_vim_leave_pre"),
  once = true,
  callback = function()
    eve.state.dispose()
  end,
})

vim.api.nvim_create_autocmd({ "WinNew", "WinEnter" }, {
  group = eve.nvim.augroup("state_on_WinNew_WinEnter"),
  callback = function(arg)
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local bufname = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local buftype = vim.bo[bufnr].buftype ---@type string
    local filetype = vim.bo[bufnr].filetype ---@type string

    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(winnr) then
        return
      end

      local bufnr2 = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local bufname2 = vim.api.nvim_buf_get_name(bufnr2) ---@type string
      local buftype2 = vim.bo[bufnr2].buftype ---@type string
      local filetype2 = vim.bo[bufnr2].filetype ---@type string
      eve.debug.log_silent({
        arg = arg,
        winnr = winnr,
        b1 = {
          bufnr = bufnr,
          bufname = bufname,
          buftype = buftype,
          filetype = filetype,
        },
        b2 = {
          bufnr = bufnr2,
          bufname = bufname2,
          buftype = buftype2,
          filetype = filetype2,
        },
      })
    end)
  end,
})

vim.api.nvim_create_autocmd({ "VimEnter", "SessionLoadPost" }, {
  group = eve.nvim.augroup("state_on_vim_enter_or_session_load_post"),
  callback = function()
    vim.schedule(function()
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
        if eve.path.is_exist_dirpath(filepath) then
          local new_filepath = eve.state.buf.pick_filepath(filepath, existed_filepaths) ---@type string|nil
          if new_filepath ~= nil then
            existed_filepaths[new_filepath] = true
            if eve.buf.is_valid(bufnr) then
              local filetype = vim.bo[bufnr].filetype ---@type string
              vim.b[bufnr][eve.var.Names.FLAG_SOURCEFILE] = true
              vim.bo[bufnr].filetype = #filetype > 0 and filetype or "text" ---@type string
              vim.bo[bufnr].swapfile = false
              vim.api.nvim_buf_set_name(bufnr, new_filepath)
              eve.state.buf.refresh(bufnr)
            end
          end
        end
      end

      eve.state.status.dirtier_statusline:mark_dirty()
      eve.state.status.dirtier_tabline:mark_dirty()
      eve.state.refresh()
    end)
  end,
})

vim.api.nvim_create_autocmd("TabEnter", {
  group = eve.nvim.augroup("state_on_tab_enter"),
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer

    eve.state.tab.tab_history:push(tabnr)
    eve.state.status.dirtier_statusline:mark_dirty()
    eve.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("TabClosed", {
  group = eve.nvim.augroup("state_on_tab_closed"),
  callback = function()
    local tabnr_last = eve.state.tab.tab_history:present() ---@type integer|nil
    vim.schedule(function()
      if tabnr_last ~= nil and vim.api.nvim_tabpage_is_valid(tabnr_last) then
        vim.api.nvim_set_current_tabpage(tabnr_last)
      end
      eve.state.refresh()
    end)
    eve.state.status.dirtier_statusline:mark_dirty()
    eve.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete" }, {
  group = eve.nvim.augroup("state_on_buf_delete"),
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    vim.schedule(function()
      eve.state.status.dirtier_tabline:mark_dirty()
      eve.state.tab.on_buf_delete(tabnr)
    end)
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  group = eve.nvim.augroup("state_on_buf_win_enter"),
  callback = function(arg)
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    local bufnr = arg.buf ---@type integer

    vim.schedule(function()
      eve.state.win.on_buf_enter(winnr, bufnr)
      eve.state.tab.on_buf_enter(tabnr, winnr, bufnr)

      eve.state.status.dirty_winline_nr:next(winnr)
      eve.state.status.dirtier_statusline:mark_dirty()
      eve.state.status.dirtier_tabline:mark_dirty()
    end)
  end,
})

vim.api.nvim_create_autocmd({ "WinNew", "WinEnter" }, {
  group = eve.nvim.augroup("state_on_win_enter"),
  callback = function(arg)
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    local bufnr = arg.buf ---@type integer

    vim.schedule(function()
      eve.state.tab.on_buf_enter(tabnr, winnr, bufnr)
      eve.state.editor.on_win_enter(winnr)

      eve.state.status.dirty_winline_nr:next(winnr)
      eve.state.status.dirtier_statusline:mark_dirty()
      eve.state.status.dirtier_tabline:mark_dirty()
    end)
  end,
})

vim.api.nvim_create_autocmd("WinClosed", {
  group = eve.nvim.augroup("state_on_win_closed"),
  callback = function(args)
    local winnr = type(args.file) == "string" and tonumber(args.file) or nil ---@type integer|nil
    if type(winnr) == "number" then
      eve.state.status.maximized_winnrs[winnr] = nil
    end

    eve.state.win.on_win_closed(winnr)
    eve.state.status.dirtier_statusline:mark_dirty()
    eve.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
  group = eve.nvim.augroup("state_on_mode_changed"),
  callback = function()
    eve.constant.hlgroup.common.on_mode_changed()
  end,
})

vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = eve.nvim.augroup("state_on_diagnostic_changed"),
  callback = function()
    eve.state.status.dirtier_statusline:mark_dirty()
    eve.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
  group = eve.nvim.augroup("state_on_content_changed"),
  callback = function()
    eve.state.status.dirtier_statusline:mark_dirty()
    eve.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("CursorHold", {
  group = eve.nvim.augroup("state_on_cursor_hold"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    eve.state.status.dirty_winline_nr:next(winnr)
    eve.state.status.dirtier_statusline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("LspProgress", {
  group = eve.nvim.augroup("state_on_lsp_progress"),
  callback = function(args)
    local data = args.data.params.value
    local progress = ""

    if data.percentage then
      local icon = eve.fn.spinner() ---@type string
      progress = icon .. " " .. data.percentage .. "%% "
    end

    local str = progress .. (data.message or "") .. " " .. (data.title or "")
    local lsp_msg = data.kind == "end" and "" or str ---@type string
    eve.state.status.lsp_msg:next(lsp_msg)

    if data.kind == "end" then
      eve.state.status.suppress_warning:next(false)
    end
  end,
})

vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
  group = eve.nvim.augroup("state_on_recording"),
  callback = function()
    eve.state.status.dirtier_statusline:mark_dirty()
  end,
})

---! Auto resize splits when window got resized.
vim.api.nvim_create_autocmd("VimResized", {
  group = eve.nvim.augroup("state_on_vim_resized"),
  callback = function()
    ---Switch to a fixed window to avoid the current floating window being taken affect by `wincmd =`
    local tabnr_cur = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr_cur = vim.api.nvim_tabpage_get_win(tabnr_cur) ---@type integer
    local winnr_fixed = eve.win.find_fixed_by_filetype(tabnr_cur) or winnr_cur ---@type integer

    if winnr_cur ~= winnr_fixed then
      vim.api.nvim_tabpage_set_win(tabnr_cur, winnr_fixed)
    end
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. tabnr_cur)

    vim.api.nvim_tabpage_set_win(tabnr_cur, winnr_cur)
    vim.schedule(function()
      eve.widget.resize()

      eve.state.status.dirtier_statusline:mark_dirty()
      eve.state.status.dirtier_tabline:mark_dirty()

      if eve.env.IS_TMUX then
        local is_tmux_pane_zoomed = eve.tmux.is_tmux_pane_zoomed() ---@type boolean
        eve.state.status.tmux_zen_mode:next(is_tmux_pane_zoomed)
      end
    end)
  end,
})

vim.api.nvim_create_autocmd("WinResized", {
  group = eve.nvim.augroup("state_on_win_resized"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    eve.state.status.dirty_winline_nr:next(winnr)
    eve.state.status.dirtier_tabline:mark_dirty()
  end,
})
