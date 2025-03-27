---@class eve.state.qflist.data
---@field public history                eve.std.collection.history.ISerializedData

---@class eve.state.qflist.state
---@field public history                eve.std.collection.IHistory
---
---@field public backward               fun(): nil
---@field public forward                fun(): nil
---@field public is_quickfix_opened     fun(): boolean
---@field public open_qflist            fun(prefer_trouble: boolean): nil
---@field public set_qflist             fun(qflist: eve.t.IQuickFixItem[]|nil): nil
---@field public push                   fun(qflist: eve.t.IQuickFixItem[]|nil): nil

---@class eve.state.qflist : eve.state.qflist.state
---@field public defaults               fun(): eve.state.qflist.data
---@field public dump                   fun(): eve.state.qflist.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.qflist.data
local M = {}

---@return eve.state.qflist.data
function M.defaults()
  ---@type eve.state.qflist.data
  return {
    history = { present = 0, stack = {} },
  }
end

---@param data                        any
---@return eve.state.qflist.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.qflist.data
  if type(data) == "table" then
    if type(data.history) == "table" then
      if type(data.history.present) == "number" then
        resolved.history.present = data.history.present
      end
      if type(data.history.stack) == "table" then
        resolved.history.stack = data.history.stack
      end
    end
  end

  ---@type eve.state.qflist.data
  return resolved
end

---@return eve.state.qflist.data
function M.dump()
  ---@type eve.std.collection.history.ISerializedData
  local history = M.history and M.history:dump() or { present = 0, stack = {} }

  ---@type eve.state.qflist.data
  return {
    history = history,
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.qflist.data

  ---@type eve.std.collection.IHistory
  local history = M.history or eve.std.History.new({
    name = "qflist",
    capacity = 100,
  })
  history:load(data.history)
  M.history = history
end

----------------------------------------------------------------------------------------------------

---@type eve.std.collection.IHistory
M.history = eve.std.History.new({
  name = "qflist",
  capacity = 100,
})

---@return nil
function M.backward()
  local qflist_cur = M.history:present() ---@type eve.t.IQuickFixItem[]|nil
  if qflist_cur == nil then
    return
  end

  local qflist_prev = M.history:backward() ---@type eve.t.IQuickFixItem[]|nil
  if qflist_prev == nil or qflist_prev == qflist_cur then
    return
  end

  if #qflist_prev > 0 then
    M.set_qflist(qflist_prev)
  end
end

---@return nil
function M.forward()
  local qflist_cur = M.history:present() ---@type eve.t.IQuickFixItem[]|nil
  if qflist_cur == nil then
    return
  end

  local qflist_next = M.history:forward() ---@type eve.t.IQuickFixItem[]|nil
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
    if buftype == "quickfix" then
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
---@return nil
function M.set_qflist(qflist)
  if qflist ~= nil and #qflist > 0 then
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

  local qflist_cur = M.history:present() ---@type eve.t.IQuickFixItem[]|nil
  if qflist_cur == nil or not eve.std.fn.equals_deep(qflist_cur, qflist) then
    M.history:push(qflist)
    M.set_qflist(qflist)
  end
end

return M
