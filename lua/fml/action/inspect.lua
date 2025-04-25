local __module_name__ = "fml.action.inspect" ---@type string

---@class fml.action.inspect
local M = {}

---@return nil
function M.inspect_buf()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local meta = eve.state.buf.resolve(bufnr) ---@type eve.state.buf.meta.state|nil

  if meta == nil then
    eve.reporter.info({
      from = __module_name__,
      subject = "inspect_buf",
      details = {
        base = {
          bufnr = bufnr,
          buflisted = vim.bo[bufnr].buflisted,
          buftype = vim.bo[bufnr].buftype,
          filetype = vim.bo[bufnr].filetype,
          filepath = vim.api.nvim_buf_get_name(bufnr),
          is_sourcefile = vim.b[bufnr][eve.var.Names.FLAG_SOURCEFILE],
        },
        meta = vim.NIL,
      },
    })
    return
  end

  eve.reporter.info({
    from = __module_name__,
    subject = "inspect_buf",
    details = {
      base = {
        bufnr = bufnr,
        buflisted = vim.bo[bufnr].buflisted,
        buftype = vim.bo[bufnr].buftype,
        filetype = vim.bo[bufnr].filetype,
        filepath = vim.api.nvim_buf_get_name(bufnr),
        is_sourcefile = vim.b[bufnr][eve.var.Names.FLAG_SOURCEFILE],
      },
      meta = meta,
    },
  })
end

---@return nil
function M.inspect_pos()
  vim.show_pos()
end

---@return nil
function M.inspect_state()
  local cwd = eve.path.cwd() ---@type string
  local workspace = eve.path.workspace() ---@type string
  local full_state = eve.state.dump() ---@type eve.state.data

  eve.reporter.info({
    from = __module_name__,
    subject = "inspect_state",
    details = {
      path = {
        cwd = cwd,
        workspace = workspace,
      },
      state = {
        theme = full_state.theme,
        bookmarks = full_state.bookmark,
        flight = full_state.flight,
        lsp = full_state.lsp,
        options = full_state.option,
        plugins = full_state.plugin,
      },
    },
  })
end

---@return nil
function M.inspect_state_full()
  local cwd = eve.path.cwd() ---@type string
  local workspace = eve.path.workspace() ---@type string

  eve.reporter.info({
    from = __module_name__,
    subject = "inspect_state_full",
    details = {
      path = {
        cwd = cwd,
        workspace = workspace,
      },
      state = eve.state.dump(),
    },
  })
end

---@return nil
function M.inspect_tab()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = eve.state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil

  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  local tabid = eve.table.find_index(tabnrs, tabnr) or 1 ---@type integer

  if meta == nil then
    eve.reporter.info({
      from = __module_name__,
      subject = "inspect_tab",
      details = {
        base = {
          tabnr = tabnr,
          winnr_command = eve.state.editor.get_winnr_command(),
          winnr_fixed = eve.state.editor.get_winnr_fixed(),
          winnr_sourcefile = eve.state.editor.get_winnr_sourcefile(),
        },
        meta = vim.NIL,
      },
    })
    return
  end

  eve.reporter.info({
    from = __module_name__,
    subject = "inspect_tab",
    details = {
      base = {
        tabnr = tabnr,
        winnr_command = eve.state.editor.get_winnr_command(),
        winnr_fixed = eve.state.editor.get_winnr_fixed(),
        winnr_sourcefile = eve.state.editor.get_winnr_sourcefile(),
      },
      meta = meta:dump(tabid),
    },
  })
end

---@return nil
function M.inspect_tree()
  vim.treesitter.inspect_tree()
  vim.api.nvim_input("I")
end

---@return nil
function M.inspect_window()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer

  local buftype = vim.bo[bufnr].buftype ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string

  local meta_tab = eve.state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  local meta_win = eve.state.win.resolve(winnr) ---@type eve.state.win.meta.state|nil
  local meta_buf = eve.state.buf.resolve(bufnr) ---@type eve.state.buf.meta.state|nil

  eve.reporter.info({
    from = __module_name__,
    subject = "inspect_window",
    details = {
      _ = {
        bufnr = bufnr,
        tabnr = tabnr,
        winnr = winnr,
      },
      basic = {
        buftype = buftype or vim.NIL,
        filetype = filetype or vim.NIL,
        filepath = filepath or vim.NIL,
        focusable = eve.win.is_focusable(winnr),
        projectable = eve.win.is_projectable(winnr),
        sourcefile = eve.win.is_sourcefile(winnr),
        swappable = eve.win.is_swappable(winnr),
      },
      z_meta = {
        buf = meta_buf,
        tab = meta_tab,
        win = meta_win,
      },
    },
  })
end

return M
