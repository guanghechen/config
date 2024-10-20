---@class ghc.action.debug
local M = {}

---@return nil
function M.show_inspect()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local buftype = vim.bo[bufnr].buftype ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string

  local winnr_cur = eve.locations.get_current_winnr() ---@type integer|nil
  local bufnr_cur = eve.locations.get_current_bufnr() ---@type integer|nil

  eve.reporter.info({
    from = "ghc.action.debug",
    subject = "inspect",
    details = {
      tabnr = tabnr,
      winnr = winnr,
      bufnr = bufnr,
      buftype = buftype or "nil",
      filetype = filetype or "nil",
      bufnr_cur = bufnr_cur,
      winnr_cur = winnr_cur,
    },
  })
end

---@return nil
function M.show_inspect_pos()
  vim.show_pos()
end

---@return nil
function M.show_inspect_tree()
  vim.cmd("InspectTree")
end

---@return nil
function M.show_state()
  local data = eve.context.dump() ---@type t.eve.context.data
  eve.reporter.info({
    from = "ghc.action.debug",
    subject = "show_state",
    details = { data = data },
  })
end

return M
