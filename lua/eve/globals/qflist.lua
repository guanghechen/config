local History = require("eve.collection.history")
local constants = require("eve.std.constants")
local util = require("eve.std.util")

---@type eve.t.collection.IHistory
local qflist_history = History.new({
  name = "qflist",
  capacity = 100,
})

---@class eve.globals.qflist
local M = {}

---@return nil
function M.backward()
  local qflist_cur = qflist_history:present() ---@type eve.t.IQuickFixItem[]|nil
  if qflist_cur == nil then
    return
  end

  local qflist_prev = qflist_history:backward() ---@type eve.t.IQuickFixItem[]|nil
  if qflist_prev == nil or qflist_prev == qflist_cur then
    return
  end

  if #qflist_prev > 0 then
    M.set_qflist(qflist_prev)
  end
end

---@return nil
function M.forward()
  local qflist_cur = qflist_history:present() ---@type eve.t.IQuickFixItem[]|nil
  if qflist_cur == nil then
    return
  end

  local qflist_next = qflist_history:forward() ---@type eve.t.IQuickFixItem[]|nil
  if qflist_next == nil or qflist_next == qflist_cur then
    return
  end

  if #qflist_next > 0 then
    M.set_qflist(qflist_next)
  end
end

---@return boolean
function M.is_quickfix_opened()
  local winnrs = vim.api.nvim_list_wins() ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local buftype = vim.bo[bufnr].buftype ---@type string
    if buftype == constants.BT_QUICKFIX then
      return true
    end
  end
  return false
end

---@param prefer_trouble                boolean
---@return nil
function M.open_qflist(prefer_trouble)
  if prefer_trouble then
    ---@diagnostic disable-next-line: param-type-mismatch
    local ok = pcall(vim.cmd, "Trouble qflist toggle")
    if ok then
      return
    end
  end
  vim.cmd([[botright copen]])
end

---@param qflist                        eve.t.IQuickFixItem[]|nil
function M.set_qflist(qflist)
  if qflist ~= nil or #qflist > 0 then
    vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
    vim.fn.setqflist(qflist, "r")
    vim.fn.setqflist({}, "a", { title = "" })
    vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
  end
end

---@param qflist                        eve.t.IQuickFixItem[]|nil
---@return nil
function M.push(qflist)
  if qflist == nil or #qflist < 1 then
    return
  end

  local qflist_cur = qflist_history:present() ---@type eve.t.IQuickFixItem[]|nil
  if qflist_cur == nil or not util.deep_equals(qflist_cur, qflist) then
    qflist_history:push(qflist)
    M.set_qflist(qflist)
  end
end

return M
