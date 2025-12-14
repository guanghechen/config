local __module_name__ = "fml.action.inspect" ---@type string

---@class fml.action.inspect
local M = {}

---@return nil
function M.inspect_buf()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local meta = era.buf.resolve(bufnr, false) ---@type era.buf.IMeta|nil

  ark.reporter.info({
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
  local cwd = dot.path.cwd() ---@type string
  local workspace = dot.path.workspace() ---@type string
  local full_state = era.context.dump() ---@type era.context.data

  ark.reporter.info({
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
        status = era.state.status.dump(),
      },
    },
  })
end

---@return nil
function M.inspect_state_full()
  local cwd = dot.path.cwd() ---@type string
  local workspace = dot.path.workspace() ---@type string

  ark.reporter.info({
    from = __module_name__,
    subject = "inspect_state_full",
    details = {
      path = {
        cwd = cwd,
        workspace = workspace,
      },
      state = era.context.dump(),
    },
  })
end

---@return nil
function M.inspect_tab()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = era.tab.resolve(tabnr, false) ---@type era.tab.IMeta|nil

  if meta == nil then
    ark.reporter.info({
      from = __module_name__,
      subject = "inspect_tab",
      details = {
        base = {
          tabnr = tabnr,
          winnr_command = era.state.status.get_winnr_command(),
        },
        meta = vim.NIL,
      },
    })
    return
  end

  ark.reporter.info({
    from = __module_name__,
    subject = "inspect_tab",
    details = {
      base = {
        tabnr = tabnr,
        winnr_command = era.state.status.get_winnr_command(),
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

  local meta_tab = era.tab.resolve(tabnr, false) ---@type era.tab.IMeta|nil
  local meta_win = era.win.resolve(winnr, false) ---@type era.win.IMeta|nil
  local meta_buf = era.buf.resolve(bufnr, false) ---@type era.buf.IMeta|nil

  ark.reporter.info({
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
        focusable = era.win.is_focusable(winnr),
        projectable = era.win.is_projectable(winnr),
        sourcefile = era.win.is_sourcefile(winnr),
        swappable = era.win.is_swappable(winnr),
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
