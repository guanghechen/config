local path = require("fml.std.path")
local state = require("fml.api.state")

---@class fml.api.buf
local M = require("fml.api.buf.mod")

---@param buf_history                   fml.types.collection.IHistory
---@param bufnrs                        integer[]
---@return nil
function M.rearrange_buf_history(buf_history, bufnrs)
  local buf_history_reverse_list = {} ---@type integer[]
  local buf_history_unvisited_list = {} ---@type integer[]
  local buf_history_set = {} ---@type table<integer, boolean>

  while true do
    local bufnr = buf_history:present() ---@type integer|nil
    if bufnr == nil then
      break
    end
    local buf = state.bufs[bufnr]
    if buf and buf.alive and vim.api.nvim_buf_is_valid(bufnr) then
      buf_history_set[bufnr] = true
      table.insert(buf_history_reverse_list, bufnr)
    end
    buf_history:back(1)
  end

  for _, bufnr in ipairs(bufnrs) do
    local buf = state.bufs[bufnr]
    if buf and buf.alive and not buf_history_set[bufnr] and vim.api.nvim_buf_is_valid(bufnr) then
      table.insert(buf_history_unvisited_list, bufnr)
    end
  end

  buf_history:clear()
  for i = #buf_history_unvisited_list, 1, -1 do
    buf_history:push(buf_history_unvisited_list[i])
  end
  for i = #buf_history_reverse_list, 1, -1 do
    buf_history:push(buf_history_reverse_list[i])
  end
end

---@param bufnrs                        integer[]
function M.rearrange_bufs(bufnrs)
  local k = 1 ---@type integer
  local N = #bufnrs ---@type integer
  for i = 1, N do
    local bufnr = bufnrs[i]
    local buf = state.bufs[bufnr]
    if buf and buf.alive then
      bufnrs[k] = bufnr
      k = k + 1
      break
    end
  end
  for i = k, N do
    bufnrs[i] = nil
  end
end

---@return nil
function M.rebuild()
  local bufs = {} ---@type table<integer, fml.api.state.IBufItem>
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.buflisted(bufnr) then
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local filename = path.basename(filepath) ---@type string

      ---@type fml.api.state.IBufItem
      local item = {
        bufnr = bufnr,
        alive = true,
        pinned = false,
        filepath = filepath,
        filename = filename,
      }
      bufs[bufnr] = item
    end
  end
  state.bufs = bufs

  ---update tab.$.buf_history
  for _, tab in pairs(state.tabs) do
    M.rearrange_bufs(tab.bufnrs)
    M.rearrange_buf_history(tab.buf_history, tab.bufnrs)

    ---update tab.$.win.$.buf_history
    for _, win in pairs(tab.wins) do
      M.rearrange_buf_history(win.buf_history, {})
    end
  end
end

---@param bufnr                         integer
---@return nil
function M.refresh(bufnr)
  local buf = state.bufs[bufnr]
  if not vim.api.nvim_buf_is_valid(bufnr) then
    if buf ~= nil then
      buf.alive = false
    end
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filename = path.basename(filepath) ---@type string

  if buf ~= nil and buf.alive then
    buf.filepath = filepath
    buf.filename = filename
  else
    ---@type fml.api.state.IBufItem
    buf = {
      bufnr = bufnr,
      alive = true,
      pinned = false,
      filepath = filepath,
      filename = filename,
    }
    table.insert(state.bufs, buf)
  end
end
