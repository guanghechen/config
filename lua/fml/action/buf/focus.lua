local __module_name__ = "fml.action.buf" ---@type string

local reporter = require("eve.builtin.reporter")

local functional = require("eve.lib.functional")
local state = require("eve.state")

---@class fml.action.buf
local M = {}

---@param context                       eve.command.IContext
---@param bufnr                         integer the stable unique number of the buffer
---@return nil
function M.open(context, bufnr)
  local winnr = context.winnr ---@type integer
  if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end
end

---@param context                       eve.command.IContext
---@param bufid                         integer the index of buffer list
---@return nil
function M.focus(context, bufid)
  local tabnr = context.tabnr ---@type integer
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
  M.open(context, bufs[bufid_next].bufnr)
end

---@param context                       eve.command.IContext
---@param step                          integer|nil
---@return nil
function M.focus_left(context, step)
  local tabnr = context.tabnr ---@type integer
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

  local bufnr_cur = context.bufnr ---@type integer
  local bufs = tab_meta.bufs ---@type eve.t.state.tab.buf.state[]
  local _, bufid_cur = tab_meta:find_buf(bufnr_cur)

  if bufid_cur ~= nil then
    step = math.max(1, step or vim.v.count1 or 1)
    local bufid_next = functional.navigate_circular(bufid_cur, -step, #bufs)
    M.open(context, bufs[bufid_next].bufnr)
  end
end

---@param context                       eve.command.IContext
---@param step                          integer|nil
---@return nil
function M.focus_right(context, step)
  local tabnr = context.tabnr ---@type integer
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

  local bufnr_cur = context.bufnr ---@type integer
  local bufs = tab_meta.bufs ---@type eve.t.state.tab.buf.state[]
  local _, bufid_cur = tab_meta:find_buf(bufnr_cur)

  if bufid_cur ~= nil then
    step = math.max(1, step or vim.v.count1 or 1)
    local bufid_next = functional.navigate_circular(bufid_cur, step, #bufs)
    M.open(context, bufs[bufid_next].bufnr)
  end
end

return M
