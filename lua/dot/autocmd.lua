vim.api.nvim_create_autocmd("BufDelete", {
  group = ark.nvim.augroup("bootstrap_on_BufDelete"),
  callback = function(event)
    local bufnr = event.buf ---@type integer
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    dot.tab.on_buf_delete(tabnr)
    dot.buf.on_close(bufnr)
    dot.term.on_buf_deleted(bufnr)
  end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = ark.nvim.augroup("bootstrap_on_BufWinEnter"),
  callback = function(event)
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    local bufnr = event.buf ---@type integer

    dot.win.on_buf_enter(winnr, bufnr)
    dot.tab.on_buf_enter(tabnr, bufnr)

    dot.state.status.dirty_winline_nr:next(winnr)
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()

    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    if yoz.path.is_absolute(filepath) and yoz.path.is_exist_file(filepath) then
      local uuid = dot.tree.Filetree.uuid(filepath) ---@type string
      dot.context.frecency.files:access(uuid)
    end
  end,
})

vim.api.nvim_create_autocmd("CursorHold", {
  group = ark.nvim.augroup("bootstrap_on_CursorHold"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    dot.state.status.dirtier_statusline:mark_dirty()

    if dot.win.is_sourcefile(winnr) then
      dot.state.status.dirty_winline_nr:next(winnr)
    end
  end,
})

vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = ark.nvim.augroup("bootstrap_on_DiagnosticChanged"),
  callback = function()
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = ark.nvim.augroup("bootstrap_on_FileType"),
  callback = function(event)
    local bufnr = event.buf ---@type integer|nil
    if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local filetype = vim.bo[bufnr].filetype ---@type string
    if dot.filetype.is_not_sourcefile(filetype) then
      vim.b[bufnr].miniindentscope_disable = true
      vim.b[bufnr].minipairs_disable = true
    end
  end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
  group = ark.nvim.augroup("bootstrap_on_ModeChanged"),
  callback = function()
    dot.theme.hlgroup.common.on_mode_changed()
  end,
})

vim.api.nvim_create_autocmd("OptionSet", {
  group = ark.nvim.augroup("bootstrap_on_OptionSet_modified"),
  pattern = "modified",
  callback = function()
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("TabClosed", {
  group = ark.nvim.augroup("bootstrap_on_TabClosed"),
  callback = function(event)
    local tabnr = type(event.file) == "string" and tonumber(event.file) or nil ---@type integer|nil
    dot.tab.on_close(tabnr)

    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("TabEnter", {
  group = ark.nvim.augroup("bootstrap_on_TabEnter"),
  callback = function()
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd({ "VimEnter", "SessionLoadPost" }, {
  group = ark.nvim.augroup("state_on_VimEnter"),
  callback = function()
    vim.schedule(function()
      local cwd = dot.path.cwd() ---@type string
      local existed_filepaths = {} ---@type table<string, boolean>
      local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
      for _, bufnr in ipairs(bufnrs) do
        local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local filepath = dot.path.resolve(cwd, filename) ---@type string
        existed_filepaths[filepath] = true
      end

      for _, bufnr in ipairs(bufnrs) do
        local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local filepath = dot.path.resolve(cwd, filename) ---@type string
        if yoz.path.is_exist_directory(filepath) then
          local new_filepath = dot.buf.pick_filepath(filepath, existed_filepaths) ---@type string|nil
          if new_filepath ~= nil then
            existed_filepaths[new_filepath] = true
            if dot.buf.is_valid(bufnr) then
              local filetype = vim.bo[bufnr].filetype ---@type string
              vim.bo[bufnr].filetype = #filetype > 0 and filetype or "text" ---@type string
              vim.bo[bufnr].swapfile = false
              vim.api.nvim_buf_set_name(bufnr, new_filepath)
            end
          end
        end
      end

      dot.tab.refresh()
      dot.state.status.dirtier_statusline:mark_dirty()
      dot.state.status.dirtier_tabline:mark_dirty()
    end)

    if ark.env.IS_TMUX then
      vim.schedule(function()
        local is_tmux_pane_zoomed = ark.tmux.is_tmux_pane_zoomed() ---@type boolean
        dot.state.status.tmux_zen_mode:next(is_tmux_pane_zoomed)
      end)
    end
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = ark.nvim.augroup("state_on_VimLeavePre"),
  once = true,
  callback = function()
    dot.state.status.dispose()
  end,
})

---! Auto resize splits when window got resized.
vim.api.nvim_create_autocmd("VimResized", {
  group = ark.nvim.augroup("bootstrap_on_VimResized"),
  callback = function()
    ---Switch to a fixed window to avoid the current floating window being taken affect by `wincmd =`
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    dot.tab.focus_win_fixed(tabnr)

    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. tabnr)

    vim.api.nvim_tabpage_set_win(tabnr, winnr)
    vim.schedule(function()
      if ark.env.IS_TMUX then
        vim.schedule(function()
          local is_tmux_pane_zoomed = ark.tmux.is_tmux_pane_zoomed() ---@type boolean
          dot.state.status.tmux_zen_mode:next(is_tmux_pane_zoomed)
        end)
      end

      dot.state.widget.resize()
      dot.state.status.dirtier_statusline:mark_dirty()
      dot.state.status.dirtier_tabline:mark_dirty()
    end)
  end,
})

vim.api.nvim_create_autocmd("WinClosed", {
  group = ark.nvim.augroup("bootstrap_on_WinClosed"),
  callback = function(event)
    local winnr = type(event.file) == "string" and tonumber(event.file) or nil ---@type integer|nil
    dot.win.on_close(winnr)

    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("WinEnter", {
  group = ark.nvim.augroup("bootstrap_on_WinEnter"),
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer

    vim.schedule(function()
      if not vim.api.nvim_tabpage_is_valid(tabnr) or not vim.api.nvim_win_is_valid(winnr) then
        return
      end

      local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
      if dot.win.is_sourcefile(winnr) then
        if meta ~= nil then
          meta.winnr_sourcefile:next(winnr)
        end
      end
      if dot.win.is_fixed(winnr) then
        if meta ~= nil then
          meta.winnr_fixed:next(winnr)
        end
      else
        if meta ~= nil then
          local winnr_float_last = meta.winnr_float:snapshot() ---@type integer|nil
          if winnr_float_last ~= nil and winnr_float_last > 0 and vim.api.nvim_win_is_valid(winnr_float_last) then
            local winhighlight = vim.wo[winnr_float_last].winhighlight ---@type string
            local winhighlight_next = winhighlight:gsub("FloatBorder:FloatActiveBorder", "FloatBorder:FloatBorder")
            vim.wo[winnr_float_last].winhighlight = winhighlight_next
          end
          meta.winnr_float:next(winnr)
        end
        local winhighlight = vim.wo[winnr].winhighlight ---@type string
        local winhighlight_next = winhighlight:gsub("FloatBorder:FloatBorder", "FloatBorder:FloatActiveBorder") ---@type string
        vim.wo[winnr].winhighlight = winhighlight_next
      end

      dot.state.status.dirty_winline_nr:next(winnr)
      dot.state.status.dirtier_statusline:mark_dirty()
      dot.state.status.dirtier_tabline:mark_dirty()
    end)
  end,
})

vim.api.nvim_create_autocmd("WinResized", {
  group = ark.nvim.augroup("bootstrap_on_WinResized"),
  callback = function()
    vim.schedule(function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      dot.state.status.dirty_winline_nr:next(winnr)
    end)
  end,
})

----------------------------------------------------------------------------------------------------

vim.api.nvim_create_autocmd("LspDetach", {
  group = ark.nvim.augroup("bootstrap_on_LspDetach"),
  callback = function(args)
    local client_id = args.data.client_id
    local client = vim.lsp.get_client_by_id(client_id)
    local bufnr = args.buf
    if client ~= nil then
      dot.lsp.on_detach(client, bufnr)
    end
  end,
})

vim.api.nvim_create_autocmd("LspProgress", {
  group = ark.nvim.augroup("bootstrap_on_LspProgress"),
  callback = function(event)
    local data = event.data.params.value
    local progress = ""

    if data.percentage then
      local icon = ark.anim.spinner() ---@type string
      progress = icon .. " " .. data.percentage .. "%% "
    end

    local str = progress .. (data.message or "") .. " " .. (data.title or "")
    local msg_lsp = data.kind == "end" and "" or str ---@type string
    dot.state.status.msg_lsp:next(msg_lsp)

    if data.kind == "end" then
      dot.state.status.suppress_warning:next(false)
    end
  end,
})

----------------------------------------------------------------------------------------------------

if 1 == 0 then
  vim.api.nvim_create_autocmd({ "WinNew", "WinEnter" }, {
    group = ark.nvim.augroup("debug_on_WinNew_WinEnter"),
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
        ark.debug.log_silent({
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
end
