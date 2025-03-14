---@class eve.state.qflist.data
---@field public history                eve.collection.history.ISerializedData

---@class eve.state.qflist.state
---@field public history                eve.collection.IHistory
---
---@field public backward               fun(): nil
---@field public forward                fun(): nil
---@field public is_quickfix_opened     fun(): boolean
---@field public open_qflist            fun(prefer_trouble: boolean): nil
---@field public set_qflist             fun(qflist: eve.t.IQuickFixItem[]|nil): nil
---@field public push                   fun(qflist: eve.t.IQuickFixItem[]|nil): nil
local S = {}

---@class eve.state.qflist
---@field public defaults               fun(): eve.state.qflist.data
---@field public dump                   fun(): eve.state.qflist.data
---@field public load                   fun(data: unknown): eve.state.qflist.state
---@field public normalize              fun(data: unknown): eve.state.qflist.data
local M = {}

---@type eve.state.qflist.state
S = {
  history = eve.col.History.new({
    name = "qflist",
    capacity = 100,
  }),
  backward = function()
    local qflist_cur = S.history:present() ---@type eve.t.IQuickFixItem[]|nil
    if qflist_cur == nil then
      return
    end

    local qflist_prev = S.history:backward() ---@type eve.t.IQuickFixItem[]|nil
    if qflist_prev == nil or qflist_prev == qflist_cur then
      return
    end

    if #qflist_prev > 0 then
      S.set_qflist(qflist_prev)
    end
  end,
  forward = function()
    local qflist_cur = S.history:present() ---@type eve.t.IQuickFixItem[]|nil
    if qflist_cur == nil then
      return
    end

    local qflist_next = S.history:forward() ---@type eve.t.IQuickFixItem[]|nil
    if qflist_next == nil or qflist_next == qflist_cur then
      return
    end

    if #qflist_next > 0 then
      S.set_qflist(qflist_next)
    end
  end,
  is_quickfix_opened = function()
    local winnrs = vim.api.nvim_list_wins() ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local buftype = vim.bo[bufnr].buftype ---@type string
      if buftype == "quickfix" then
        return true
      end
    end
    return false
  end,
  open_qflist = function(prefer_trouble)
    if prefer_trouble then
      ---@diagnostic disable-next-line: param-type-mismatch
      local ok = pcall(vim.cmd, "Trouble qflist toggle")
      if ok then
        return
      end
    end
    vim.cmd([[botright copen]])
  end,
  set_qflist = function(qflist)
    if qflist ~= nil or #qflist > 0 then
      vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
      vim.fn.setqflist(qflist, "r")
      vim.fn.setqflist({}, "a", { title = "" })
      vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
    end
  end,
  push = function(qflist)
    if qflist == nil or #qflist < 1 then
      return
    end

    local qflist_cur = S.history:present() ---@type eve.t.IQuickFixItem[]|nil
    if qflist_cur == nil or not eve.fn.equals_deep(qflist_cur, qflist) then
      S.history:push(qflist)
      S.set_qflist(qflist)
    end
  end,
}

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
  ---@type eve.collection.history.ISerializedData
  local history = S.history and S.history:dump() or { present = 0, stack = {} }

  ---@type eve.state.qflist.data
  return {
    history = history,
  }
end

---@param raw_data                      any
---@return eve.state.qflist.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.qflist.data

  ---@type eve.collection.IHistory
  local history = S.history or eve.col.History.new({
    name = "qflist",
    capacity = 100,
  })
  history:load(data.history)
  S.history = history

  return S
end

return M
