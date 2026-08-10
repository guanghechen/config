vim.api.nvim_create_autocmd("BufDelete", {
  group = stl.nvim.fn.augroup("bootstrap_on_BufDelete"),
  callback = function(event)
    local bufnr = event.buf ---@type integer
    dot.tab.on_buf_delete(bufnr)
    dot.buf.on_close(bufnr)
    era.m.term.event.on_buf_deleted(bufnr)
  end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = stl.nvim.fn.augroup("bootstrap_on_BufWinEnter"),
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
      local uuid = stl.c.Filetree.uuid(filepath) ---@type string
      dot.context.frecency.files:access(uuid)
    end
  end,
})

vim.api.nvim_create_autocmd("CursorHold", {
  group = stl.nvim.fn.augroup("bootstrap_on_CursorHold"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    dot.state.status.dirtier_statusline:mark_dirty()

    if dot.win.is_sourcefile(winnr) then
      dot.state.status.dirty_winline_nr:next(winnr)
    end
  end,
})

vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = stl.nvim.fn.augroup("bootstrap_on_DiagnosticChanged"),
  callback = function()
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = stl.nvim.fn.augroup("bootstrap_on_FileType"),
  callback = function(event)
    local bufnr = event.buf ---@type integer|nil
    if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
    if stl.filetype.is_not_sourcefile(filetype) then
      vim.b[bufnr].miniindentscope_disable = true
      vim.b[bufnr].minipairs_disable = true
    end
  end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
  group = stl.nvim.fn.augroup("bootstrap_on_ModeChanged"),
  callback = function()
    dot.theme.hlgroup.common.on_mode_changed()
  end,
})

vim.api.nvim_create_autocmd("OptionSet", {
  group = stl.nvim.fn.augroup("bootstrap_on_OptionSet_modified"),
  pattern = "modified",
  callback = function()
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("TabClosed", {
  group = stl.nvim.fn.augroup("bootstrap_on_TabClosed"),
  callback = function()
    dot.tab.on_close()

    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("TabEnter", {
  group = stl.nvim.fn.augroup("bootstrap_on_TabEnter"),
  callback = function()
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end,
})

local tmux_zen_refresh_active = true
local tmux_zen_refreshing = false
local tmux_zen_refresh_pending = false

---@return nil
local function refresh_tmux_zen_mode()
  if not stl.env.IS_TMUX or not tmux_zen_refresh_active then
    return
  end
  if tmux_zen_refreshing then
    tmux_zen_refresh_pending = true
    return
  end

  tmux_zen_refreshing = true
  stl.tmux.query_tmux_pane_zoomed(function(is_zoomed)
    tmux_zen_refreshing = false
    if not tmux_zen_refresh_active then
      tmux_zen_refresh_pending = false
      return
    end
    if tmux_zen_refresh_pending then
      tmux_zen_refresh_pending = false
      refresh_tmux_zen_mode()
      return
    end
    if is_zoomed ~= nil then
      dot.state.status.tmux_zen_mode:next(is_zoomed)
    end
  end)
end

vim.api.nvim_create_autocmd({ "VimEnter", "SessionLoadPost" }, {
  group = stl.nvim.fn.augroup("state_on_VimEnter"),
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
            if stl.nvim.buf.is_valid(bufnr) then
              local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
              vim.api.nvim_set_option_value("filetype", #filetype > 0 and filetype or "text", { buf = bufnr })
              vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
              vim.api.nvim_buf_set_name(bufnr, new_filepath)
            end
          end
        end
      end

      dot.tab.refresh()
      dot.state.status.dirtier_statusline:mark_dirty()
      dot.state.status.dirtier_tabline:mark_dirty()
    end)
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = stl.nvim.fn.augroup("state_tmux_zen_mode_on_VimEnter"),
  once = true,
  callback = refresh_tmux_zen_mode,
})

vim.api.nvim_create_autocmd("SessionLoadPost", {
  group = stl.nvim.fn.augroup("state_tmux_zen_mode_on_SessionLoadPost"),
  callback = function()
    if vim.v.vim_did_enter == 1 then
      refresh_tmux_zen_mode()
    end
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = stl.nvim.fn.augroup("state_on_VimLeavePre"),
  once = true,
  callback = function()
    tmux_zen_refresh_active = false
    tmux_zen_refresh_pending = false
    dot.state.status.dispose()
  end,
})

---! Auto resize splits when window got resized.
vim.api.nvim_create_autocmd("VimResized", {
  group = stl.nvim.fn.augroup("bootstrap_on_VimResized"),
  callback = function()
    local current_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local current_winnr = vim.api.nvim_tabpage_get_win(current_tabnr) ---@type integer

    -- Equalize windows in all tabs without using tabdo (which triggers autocmds and causes duplicate windows)
    local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
    for _, tabnr in ipairs(tabnrs) do
      local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
      if #winnrs > 0 then
        local winnr = winnrs[1] ---@type integer
        if vim.api.nvim_win_is_valid(winnr) then
          vim.api.nvim_win_call(winnr, function()
            vim.cmd("wincmd =")
          end)
        end
      end
    end

    vim.api.nvim_tabpage_set_win(current_tabnr, current_winnr)
    vim.schedule(function()
      refresh_tmux_zen_mode()

      dot.state.widget.resize()
      dot.state.status.dirtier_statusline:mark_dirty()
      dot.state.status.dirtier_tabline:mark_dirty()
    end)
  end,
})

vim.api.nvim_create_autocmd("WinClosed", {
  group = stl.nvim.fn.augroup("bootstrap_on_WinClosed"),
  callback = function(event)
    local winnr = type(event.file) == "string" and tonumber(event.file) or nil ---@type integer|nil
    dot.win.on_close(winnr)

    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end,
})

vim.api.nvim_create_autocmd("WinEnter", {
  group = stl.nvim.fn.augroup("bootstrap_on_WinEnter"),
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
      if stl.nvim.win.is_fixed(winnr) then
        if meta ~= nil then
          meta.winnr_fixed:next(winnr)
        end
      else
        if meta ~= nil then
          local winnr_float_last = meta.winnr_float:snapshot() ---@type integer|nil
          if winnr_float_last ~= nil and winnr_float_last > 0 and vim.api.nvim_win_is_valid(winnr_float_last) then
            local winhighlight = vim.api.nvim_get_option_value("winhighlight", { win = winnr_float_last }) ---@type string
            local winhighlight_next = winhighlight:gsub("FloatBorder:FloatActiveBorder", "FloatBorder:FloatBorder")
            vim.api.nvim_set_option_value(
              "winhighlight",
              winhighlight_next,
              { win = winnr_float_last, scope = "local" }
            )
          end
          meta.winnr_float:next(winnr)
        end
        local winhighlight = vim.api.nvim_get_option_value("winhighlight", { win = winnr }) ---@type string
        local winhighlight_next = winhighlight:gsub("FloatBorder:FloatBorder", "FloatBorder:FloatActiveBorder") ---@type string
        vim.api.nvim_set_option_value("winhighlight", winhighlight_next, { win = winnr, scope = "local" })
      end

      dot.state.status.dirty_winline_nr:next(winnr)
      dot.state.status.dirtier_statusline:mark_dirty()
      dot.state.status.dirtier_tabline:mark_dirty()
    end)
  end,
})

vim.api.nvim_create_autocmd("WinResized", {
  group = stl.nvim.fn.augroup("bootstrap_on_WinResized"),
  callback = function()
    vim.schedule(function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      dot.state.status.dirty_winline_nr:next(winnr)
    end)
  end,
})

----------------------------------------------------------------------------------------------------

vim.api.nvim_create_autocmd("LspDetach", {
  group = stl.nvim.fn.augroup("bootstrap_on_LspDetach"),
  callback = function(args)
    local client_id = args.data and args.data.client_id or nil
    local client = client_id and vim.lsp.get_client_by_id(client_id) or nil
    local bufnr = args.buf
    if client ~= nil then
      era.m.lsp.event.on_detach(client, bufnr)
    end

    -- Clear symbol ready status only if client has no more attached buffers
    if client_id then
      vim.schedule(function()
        local c = vim.lsp.get_client_by_id(client_id)
        if c == nil or vim.tbl_isempty(c.attached_buffers) then
          dot.state.status.lsp_symbol_ready[client_id] = nil
        end
      end)
    end
  end,
})

vim.api.nvim_create_autocmd("LspProgress", {
  group = stl.nvim.fn.augroup("bootstrap_on_LspProgress"),
  callback = function(event)
    local data = event.data.params.value
    local progress = ""

    if data.percentage then
      local icon = stl.anim.spinner() ---@type string
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
    group = stl.nvim.fn.augroup("debug_on_WinNew_WinEnter"),
    callback = function(arg)
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local bufname = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string

      vim.schedule(function()
        if not vim.api.nvim_win_is_valid(winnr) then
          return
        end

        local bufnr2 = vim.api.nvim_win_get_buf(winnr) ---@type integer
        local bufname2 = vim.api.nvim_buf_get_name(bufnr2) ---@type string
        local buftype2 = vim.api.nvim_get_option_value("buftype", { buf = bufnr2 }) ---@type string
        local filetype2 = vim.api.nvim_get_option_value("filetype", { buf = bufnr2 }) ---@type string
        stl.debug.log_silent({
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
