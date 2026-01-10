local __module_name__ = "era.m.inspect" ---@type string

---@class era.m.inspect
local M = {}

---@return nil
function M.inspect_buf()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local meta = dot.buf.resolve(bufnr, false) ---@type dot.buf.IMeta|nil

  stl.reporter.info({
    from = __module_name__,
    subject = "inspect_buf",
    details = {
      base = {
        bufnr = bufnr,
        buflisted = vim.api.nvim_get_option_value("buflisted", { buf = bufnr }),
        buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }),
        filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }),
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
  local full_state = dot.context.dump() ---@type dot.context.data

  stl.reporter.info({
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
        status = dot.state.status.dump(),
      },
    },
  })
end

---@return nil
function M.inspect_state_full()
  local cwd = dot.path.cwd() ---@type string
  local workspace = dot.path.workspace() ---@type string

  stl.reporter.info({
    from = __module_name__,
    subject = "inspect_state_full",
    details = {
      path = {
        cwd = cwd,
        workspace = workspace,
      },
      state = dot.context.dump(),
    },
  })
end

---@return nil
function M.inspect_tab()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil

  if meta == nil then
    stl.reporter.info({
      from = __module_name__,
      subject = "inspect_tab",
      details = {
        base = {
          tabnr = tabnr,
          winnr_command = dot.state.status.get_winnr_command(),
        },
        meta = vim.NIL,
      },
    })
    return
  end

  stl.reporter.info({
    from = __module_name__,
    subject = "inspect_tab",
    details = {
      base = {
        tabnr = tabnr,
        winnr_command = dot.state.status.get_winnr_command(),
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

  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string

  local meta_tab = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  local meta_win = dot.win.resolve(winnr, false) ---@type dot.win.IMeta|nil
  local meta_buf = dot.buf.resolve(bufnr, false) ---@type dot.buf.IMeta|nil

  stl.reporter.info({
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
        focusable = dot.win.is_focusable(winnr),
        projectable = dot.win.is_projectable(winnr),
        sourcefile = dot.win.is_sourcefile(winnr),
        swappable = dot.win.is_swappable(winnr),
        winbar = vim.api.nvim_get_option_value("winbar", { win = winnr }),
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
