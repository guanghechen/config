local __module_name__ = "fml.action.inspect" ---@type string

---@class fml.action.inspect
local M = {}

---@return nil
function M.inspect_buf()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local meta = eve.buf.resolve(bufnr, false) ---@type eve.builtin.buf.IMeta|nil

  std.reporter.info({
    from = __module_name__,
    subject = "inspect_buf",
    details = {
      base = {
        bufnr = bufnr,
        buflisted = vim.bo[bufnr].buflisted,
        buftype = vim.bo[bufnr].buftype,
        filetype = vim.bo[bufnr].filetype,
        filepath = vim.api.nvim_buf_get_name(bufnr),
      },
      meta = meta or vim.NIL,
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
  local full_state = eve.context.dump() ---@type eve.context.data

  std.reporter.info({
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
        status = eve.status.dump(),
      },
    },
  })
end

---@return nil
function M.inspect_state_full()
  local cwd = eve.path.cwd() ---@type string
  local workspace = eve.path.workspace() ---@type string

  std.reporter.info({
    from = __module_name__,
    subject = "inspect_state_full",
    details = {
      path = {
        cwd = cwd,
        workspace = workspace,
      },
      state = eve.context.dump(),
    },
  })
end

---@return nil
function M.inspect_tab()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = eve.tab.resolve(tabnr, false) ---@type eve.builtin.tab.IMeta|nil

  if meta == nil then
    std.reporter.info({
      from = __module_name__,
      subject = "inspect_tab",
      details = {
        base = {
          tabnr = tabnr,
          winnr_command = eve.status.get_winnr_command(),
        },
        meta = vim.NIL,
      },
    })
    return
  end

  std.reporter.info({
    from = __module_name__,
    subject = "inspect_tab",
    details = {
      base = {
        tabnr = tabnr,
        winnr_command = eve.status.get_winnr_command(),
        winnr_fixed = meta.winnr_fixed:snapshot(),
        winnr_float = meta.winnr_float:snapshot(),
        winnr_sourcefile = meta.winnr_sourcefile:snapshot(),
      },
      meta = meta,
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

  local meta_tab = eve.tab.resolve(tabnr, false) ---@type eve.builtin.tab.IMeta|nil
  local meta_win = eve.win.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  local meta_buf = eve.buf.resolve(bufnr, false) ---@type eve.builtin.buf.IMeta|nil

  std.reporter.info({
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
        winbar = vim.wo[winnr].winbar,
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
