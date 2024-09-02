local state = require("fml.api.state")
local navigate = require("eve.std.navigate")
local std_array = require("eve.std.array")

---@class fml.api.buf
local M = require("fml.api.buf.mod")

---@param bufnrs                        integer[]
---@return nil
function M.close(bufnrs)
  if #bufnrs < 1 then
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = state.tabs[tabnr] ---@type fml.types.api.state.ITabItem
  if tab ~= nil then
    for _, bufnr in ipairs(bufnrs) do
      tab.bufnr_set[bufnr] = nil
    end

    local k = 0 ---@type integer
    local N = #tab.bufnrs ---@type integer
    for i = 1, N, 1 do
      local bufnr = tab.bufnrs[i]
      if tab.bufnr_set[bufnr] then
        k = k + 1
        tab.bufnrs[k] = bufnr
      end
    end
    for i = k + 1, N, 1 do
      tab.bufnrs[i] = nil
    end
  end

  state.remove_unrefereced_bufs(bufnrs) ---@type integer
end

---@return nil
function M.close_current()
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local win = state.wins[winnr_cur] ---@type fml.types.api.state.IWinItem|nil

  ---! Set the buf to the last buf in the history before closing the current buf to avoid unexpected behaviors.
  if win ~= nil then
    local last_filepath = win.filepath_history:backward() ---@type string|nil
    local bufnr_last = state.locate_bufnr_by_filepath(last_filepath) ---@type integer|nil
    if bufnr_last ~= nil and vim.api.nvim_buf_is_valid(bufnr_last) then
      vim.api.nvim_win_set_buf(winnr_cur, bufnr_last)
    end
  end

  M.close({ bufnr_cur })
end

---@param step                          ?integer
---@return nil
function M.close_left(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = state.get_tab(tabnr) ---@type fml.types.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr_cur) or 1 ---@type integer
  local bufid_next = navigate.limit(bufid_cur, -step, #tab.bufnrs)

  local bufnrs_to_remove = {} ---@type integer[]
  local visible_bufnrs = M.get_visible_bufnrs(tabnr) ---@type table<integer, boolean>
  for id = bufid_next, bufid_cur - 1, 1 do
    local bufnr = tab.bufnrs[id] ---@type integer
    if not visible_bufnrs[bufnr] then
      local buf = state.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
      if buf == nil or not buf.pinned then
        table.insert(bufnrs_to_remove, bufnr)
      end
    end
  end

  M.close(bufnrs_to_remove)
end

---@param step                          ?integer
---@return nil
function M.close_right(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = state.get_tab(tabnr) ---@type fml.types.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr_cur) or 1 ---@type integer
  local bufid_next = navigate.limit(bufid_cur, step, #tab.bufnrs)

  local bufnrs_to_remove = {} ---@type integer[]
  local visible_bufnrs = M.get_visible_bufnrs(tabnr) ---@type table<integer, boolean>
  for id = bufid_cur + 1, bufid_next, 1 do
    local bufnr = tab.bufnrs[id] ---@type integer
    if not visible_bufnrs[bufnr] then
      local buf = state.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
      if buf == nil or not buf.pinned then
        table.insert(bufnrs_to_remove, bufnr)
      end
    end
  end

  M.close(bufnrs_to_remove)
end

---@return nil
function M.close_to_leftest()
  M.close_left(math.huge)
end

---@return nil
function M.close_to_rightest()
  M.close_right(math.huge)
end

---@return nil
function M.close_others()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = state.get_tab(tabnr) ---@type fml.types.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  local bufnrs_to_remove = {} ---@type integer[]
  local visible_bufnrs = M.get_visible_bufnrs(tabnr) ---@type table<integer, boolean>
  for _, bufnr in ipairs(tab.bufnrs) do
    if not visible_bufnrs[bufnr] then
      local buf = state.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
      if buf == nil or not buf.pinned then
        table.insert(bufnrs_to_remove, bufnr)
      end
    end
  end

  M.close(bufnrs_to_remove)
end
