local __module_name__ = "fml.action.buf" ---@type string

local functional = require("eve.lib.functional")
local reporter = require("eve.lib.reporter")
local state = require("eve.state")

---@class fml.action.buf
local M = {}

---@param bufnr                         integer the stable unique number of the buffer
---@return nil
function M.open(bufnr)
  local winnr = state.tab.get_current_winnr() ---@type integer
  if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end
end

---@param bufid                         integer the index of buffer list
---@return nil
function M.focus(bufid)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab_meta = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if tab_meta == nil then
    reporter.error({
      from = __module_name__,
      subject = "focus",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr, bufid = bufid },
    })
    return
  end

  local bufs = tab_meta.bufs ---@type eve.t.state.tab.buf.state[]
  local bufid_next = functional.navigate_circular(0, bufid, #bufs) ---@type integer
  M.open(bufs[bufid_next].bufnr)
end

---@param step                          integer|nil
---@return nil
function M.focus_left(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab_meta = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if tab_meta == nil then
    reporter.error({
      from = __module_name__,
      subject = "focus_left",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local bufs = tab_meta.bufs ---@type eve.t.state.tab.buf.state[]
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local _, bufid_cur = tab_meta:find_buf(bufnr_cur)

  if bufid_cur ~= nil then
    step = math.max(1, step or vim.v.count1 or 1)
    local bufid_next = functional.navigate_circular(bufid_cur, -step, #bufs)
    M.open(bufs[bufid_next].bufnr)
  end
end

---@param step                          integer|nil
---@return nil
function M.focus_right(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab_meta = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if tab_meta == nil then
    reporter.error({
      from = __module_name__,
      subject = "focus_right",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local bufs = tab_meta.bufs ---@type eve.t.state.tab.buf.state[]
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local _, bufid_cur = tab_meta:find_buf(bufnr_cur)

  if bufid_cur ~= nil then
    step = math.max(1, step or vim.v.count1 or 1)
    local bufid_next = functional.navigate_circular(bufid_cur, step, #bufs)
    M.open(bufs[bufid_next].bufnr)
  end
end

return M
