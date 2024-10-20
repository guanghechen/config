local History = require("eve.collection.history")
local equals = require("eve.std.equals")
local constants = require("eve.std.constants")

---@type t.eve.collection.IHistory
local qflist_history = History.new({
  name = "qflist",
  capacity = 100,
})

---@class eve.globals.qflist
local M = {}

---@return nil
function M.backward()
  local qflist_cur = qflist_history:present() ---@type t.eve.IQuickFixItem[]|nil
  if qflist_cur == nil then
    return
  end

  local qflist_prev = qflist_history:backward() ---@type t.eve.IQuickFixItem[]|nil
  if qflist_prev == nil or qflist_prev == qflist_cur then
    return
  end

  if #qflist_prev > 0 then
    vim.fn.setqflist(qflist_prev, "r")
  end
end

---@return nil
function M.forward()
  local qflist_cur = qflist_history:present() ---@type t.eve.IQuickFixItem[]|nil
  if qflist_cur == nil then
    return
  end

  local qflist_next = qflist_history:forward() ---@type t.eve.IQuickFixItem[]|nil
  if qflist_next == nil or qflist_next == qflist_cur then
    return
  end

  if #qflist_next > 0 then
    vim.fn.setqflist(qflist_next, "r")
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
      vim.cmd("cclose")
      return
    end
  end

  vim.cmd("copen")
end

---@param qflist                        t.eve.IQuickFixItem[]|nil
---@return nil
function M.push(qflist)
  if qflist == nil or #qflist < 1 then
    return
  end

  local qflist_cur = qflist_history:present() ---@type t.eve.IQuickFixItem[]|nil
  if qflist_cur == nil or not equals.deep_equals(qflist_cur, qflist) then
    qflist_history:push(qflist)
    vim.fn.setqflist(qflist, "r")
  end
end

return M
