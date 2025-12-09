vim.api.nvim_create_autocmd("BufDelete", {
  group = std.nvim.augroup("bootstrap_on_BufDelete"),
  callback = function(event)
    local bufnr = event.buf ---@type integer
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    eve.tab.on_buf_delete(tabnr)
    eve.buf.on_close(bufnr)
    eve.term.on_buf_deleted(bufnr)
  end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = std.nvim.augroup("bootstrap_on_BufWinEnter"),
  callback = function(event)
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    local bufnr = event.buf ---@type integer

    eve.win.on_buf_enter(winnr, bufnr)
    eve.tab.on_buf_enter(tabnr, bufnr)

    std.status.dirty_winline_nr:next(winnr)
    std.status.dirtier_statusline:mark_dirty()
    std.status.dirtier_tabline:mark_dirty()

    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    if std.path.is_absolute(filepath) and std.path.is_exist_filepath(filepath) then
      local uuid = std.Filetree.uuid(filepath) ---@type string
      eve.context.frecency.files:access(uuid)
    end
  end,
})

vim.api.nvim_create_autocmd("CursorHold", {
  group = std.nvim.augroup("bootstrap_on_CursorHold"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    std.status.dirtier_statusline:mark_dirty()

    if eve.win.is_sourcefile(winnr) then
      std.status.dirty_winline_nr:next(winnr)
    end
  end,
})

vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = std.nvim.augroup("bootstrap_on_DiagnosticChanged"),
  callback = function()
    std.status.dirtier_statusline:mark_dirty()
    std.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = std.nvim.augroup("bootstrap_on_FileType"),
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
  group = std.nvim.augroup("bootstrap_on_ModeChanged"),
  callback = function()
    eve.constant.hlgroup.common.on_mode_changed()
  end,
})

vim.api.nvim_create_autocmd("OptionSet", {
  group = std.nvim.augroup("bootstrap_on_OptionSet_modified"),
  pattern = "modified",
  callback = function()
    std.status.dirtier_statusline:mark_dirty()
    std.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("TabClosed", {
  group = std.nvim.augroup("bootstrap_on_TabClosed"),
  callback = function(event)
    local tabnr = type(event.file) == "string" and tonumber(event.file) or nil ---@type integer|nil
    eve.tab.on_close(tabnr)

    std.status.dirtier_statusline:mark_dirty()
    std.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("TabEnter", {
  group = std.nvim.augroup("bootstrap_on_TabEnter"),
  callback = function()
    std.status.dirtier_statusline:mark_dirty()
    std.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd({ "VimEnter", "SessionLoadPost" }, {
  group = std.nvim.augroup("state_on_VimEnter"),
  callback = function()
    vim.schedule(function()
      local cwd = std.path.cwd() ---@type string
      local existed_filepaths = {} ---@type table<string, boolean>
      local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
      for _, bufnr in ipairs(bufnrs) do
        local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local filepath = std.path.resolve(cwd, filename) ---@type string
        existed_filepaths[filepath] = true
      end

      for _, bufnr in ipairs(bufnrs) do
        local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local filepath = std.path.resolve(cwd, filename) ---@type string
        if std.path.is_exist_dirpath(filepath) then
          local new_filepath = eve.buf.pick_filepath(filepath, existed_filepaths) ---@type string|nil
          if new_filepath ~= nil then
            existed_filepaths[new_filepath] = true
            if eve.buf.is_valid(bufnr) then
              local filetype = vim.bo[bufnr].filetype ---@type string
              vim.bo[bufnr].filetype = #filetype > 0 and filetype or "text" ---@type string
              vim.bo[bufnr].swapfile = false
              vim.api.nvim_buf_set_name(bufnr, new_filepath)
            end
          end
        end
      end

      eve.tab.refresh()
      std.status.dirtier_statusline:mark_dirty()
      std.status.dirtier_tabline:mark_dirty()
    end)

    if dot.env.IS_TMUX then
      vim.schedule(function()
        local is_tmux_pane_zoomed = std.tmux.is_tmux_pane_zoomed() ---@type boolean
        std.status.tmux_zen_mode:next(is_tmux_pane_zoomed)
      end)
    end
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = std.nvim.augroup("state_on_VimLeavePre"),
  once = true,
  callback = function()
    std.status.dispose()
  end,
})

---! Auto resize splits when window got resized.
vim.api.nvim_create_autocmd("VimResized", {
  group = std.nvim.augroup("bootstrap_on_VimResized"),
  callback = function()
    ---Switch to a fixed window to avoid the current floating window being taken affect by `wincmd =`
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    eve.tab.focus_win_fixed(tabnr)

    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. tabnr)

    vim.api.nvim_tabpage_set_win(tabnr, winnr)
    vim.schedule(function()
      if dot.env.IS_TMUX then
        vim.schedule(function()
          local is_tmux_pane_zoomed = std.tmux.is_tmux_pane_zoomed() ---@type boolean
          std.status.tmux_zen_mode:next(is_tmux_pane_zoomed)
        end)
      end

      eve.widget.resize()
      std.status.dirtier_statusline:mark_dirty()
      std.status.dirtier_tabline:mark_dirty()
    end)
  end,
})

vim.api.nvim_create_autocmd("WinClosed", {
  group = std.nvim.augroup("bootstrap_on_WinClosed"),
  callback = function(event)
    local winnr = type(event.file) == "string" and tonumber(event.file) or nil ---@type integer|nil
    eve.win.on_close(winnr)

    std.status.dirtier_statusline:mark_dirty()
    std.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("WinEnter", {
  group = std.nvim.augroup("bootstrap_on_WinEnter"),
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer

    vim.schedule(function()
      if not vim.api.nvim_tabpage_is_valid(tabnr) or not vim.api.nvim_win_is_valid(winnr) then
        return
      end

      local meta = eve.tab.resolve(tabnr, false) ---@type eve.builtin.tab.IMeta|nil
      if eve.win.is_sourcefile(winnr) then
        if meta ~= nil then
          meta.winnr_sourcefile:next(winnr)
        end
      end
      if eve.win.is_fixed(winnr) then
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

      std.status.dirty_winline_nr:next(winnr)
      std.status.dirtier_statusline:mark_dirty()
      std.status.dirtier_tabline:mark_dirty()
    end)
  end,
})

vim.api.nvim_create_autocmd("WinNew", {
  group = std.nvim.augroup("bootstrap_on_WinNew"),
  callback = function(arg)
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = tonumber(arg.file) or vim.api.nvim_tabpage_get_win(tabnr) ---@type integer

    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(winnr) then
        return
      end

      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local filetype = vim.bo[bufnr].filetype ---@type string

      if filetype == "neo-tree" then
        eve.win.set_type(winnr, eve.win.Types.NEOTREE)
        return
      end
    end)
  end,
})

vim.api.nvim_create_autocmd("WinResized", {
  group = std.nvim.augroup("bootstrap_on_WinResized"),
  callback = function()
    vim.schedule(function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      std.status.dirty_winline_nr:next(winnr)
    end)
  end,
})

----------------------------------------------------------------------------------------------------

vim.api.nvim_create_autocmd("LspDetach", {
  group = std.nvim.augroup("bootstrap_on_LspDetach"),
  callback = function(args)
    local client_id = args.data.client_id
    local client = vim.lsp.get_client_by_id(client_id)
    local bufnr = args.buf
    if client ~= nil then
      eve.lsp.on_detach(client, bufnr)
    end
  end,
})

vim.api.nvim_create_autocmd("LspProgress", {
  group = std.nvim.augroup("bootstrap_on_LspProgress"),
  callback = function(event)
    local data = event.data.params.value
    local progress = ""

    if data.percentage then
      local icon = std.fn.spinner() ---@type string
      progress = icon .. " " .. data.percentage .. "%% "
    end

    local str = progress .. (data.message or "") .. " " .. (data.title or "")
    local msg_lsp = data.kind == "end" and "" or str ---@type string
    std.status.msg_lsp:next(msg_lsp)

    if data.kind == "end" then
      std.status.suppress_warning:next(false)
    end
  end,
})

----------------------------------------------------------------------------------------------------

if 1 == 0 then
  vim.api.nvim_create_autocmd({ "WinNew", "WinEnter" }, {
    group = std.nvim.augroup("debug_on_WinNew_WinEnter"),
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
        std.debug.log_silent({
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
