---@class dot.state.qflist.IItem
---@field public filename               string
---@field public lnum                   ?integer
---@field public col                    ?integer
---@field public text                   ?string

---@class dot.state.qflist
local M = {}

---@type stl.c.History
M.history = stl.c.History.new({
  name = "qflist",
  capacity = 100,
})

---@return nil
function M.backward()
  local qflist_cur = M.history:present() ---@type dot.state.qflist.IItem[]|nil
  if qflist_cur == nil then
    return
  end

  local qflist_prev = M.history:backward() ---@type dot.state.qflist.IItem[]|nil
  if qflist_prev == nil or qflist_prev == qflist_cur then
    return
  end

  if #qflist_prev > 0 then
    M.set_qflist(qflist_prev)
  end
end

---@return nil
function M.forward()
  local qflist_cur = M.history:present() ---@type dot.state.qflist.IItem[]|nil
  if qflist_cur == nil then
    return
  end

  local qflist_next = M.history:forward() ---@type dot.state.qflist.IItem[]|nil
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
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
    if buftype == "quickfix" then
      return true
    end
  end
  return false
end

---@return nil
function M.open_qflist()
  vim.cmd([[botright copen]])
end

---@param qflist                        dot.state.qflist.IItem[]|nil
---@return nil
function M.set_qflist(qflist)
  if qflist ~= nil and #qflist > 0 then
    vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
    vim.fn.setqflist(qflist, "r")
    vim.fn.setqflist({}, "a", { title = "" })
    vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
  end
end

---@param qflist                        dot.state.qflist.IItem[]|nil
---@return nil
function M.push(qflist)
  if qflist == nil or #qflist < 1 then
    return
  end

  local qflist_cur = M.history:present() ---@type dot.state.qflist.IItem[]|nil
  if qflist_cur == nil or not stl.fn.equals_deep(qflist_cur, qflist) then
    M.history:push(qflist)
    M.set_qflist(qflist)
  end
end

return M
