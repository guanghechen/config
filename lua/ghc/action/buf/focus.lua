---@class ghc.action.buf
---@field public focus_1                fun(): nil
---@field public focus_2                fun(): nil
---@field public focus_3                fun(): nil
---@field public focus_4                fun(): nil
---@field public focus_5                fun(): nil
---@field public focus_6                fun(): nil
---@field public focus_7                fun(): nil
---@field public focus_8                fun(): nil
---@field public focus_9                fun(): nil
---@field public focus_10               fun(): nil
local M = require("ghc.action.buf.mod")

---@param bufid                         integer the index of buffer list
---@return nil
function M.focus(bufid)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = fml.api.tab.get(tabnr) ---@type t.eve.context.state.tab.IItem|nil
  if tab == nil or bufid < 1 or bufid > #tab.bufnrs then
    return
  end

  local bufid_next = eve.navigate.circular(0, bufid, #tab.bufnrs)
  local bufnr_next = tab.bufnrs[bufid_next]
  fml.api.buf.go(bufnr_next)
end

---@param step                         ?integer
---@return nil
function M.focus_left(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = fml.api.tab.get(tabnr) ---@type t.eve.context.state.tab.IItem|nil
  if tab == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = eve.array.first(tab.bufnrs, bufnr_cur) ---@type integer|nil

  if bufid_cur ~= nil then
    local bufid_next = eve.navigate.circular(bufid_cur, -step, #tab.bufnrs)
    local bufnr_next = tab.bufnrs[bufid_next]
    fml.api.buf.go(bufnr_next)
  end
end

---@param step                         ?integer
---@return nil
function M.focus_right(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = fml.api.tab.get(tabnr) ---@type t.eve.context.state.tab.IItem|nil
  if tab == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = eve.array.first(tab.bufnrs, bufnr) ---@type integer|nil
  if bufid_cur ~= nil then
    local bufid_next = eve.navigate.circular(bufid_cur, step, #tab.bufnrs)
    local bufnr_next = tab.bufnrs[bufid_next]
    fml.api.buf.go(bufnr_next)
  end
end

for i = 1, 10 do
  M["focus_" .. i] = function()
    M.focus(i)
  end
end
