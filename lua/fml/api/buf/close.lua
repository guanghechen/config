local state = require("fml.api.state")
local navigate_limit = require("fml.fn.navigate_limit")
local std_array = require("fml.std.array")

---@class fml.api.buf
local M = require("fml.api.buf.mod")

---@param bufnrs                        integer[]
---@return nil
function M.close(bufnrs)
  if #bufnrs < 1 then
    return
  end

  local tab, tabnr_cur = state.get_current_tab()
  if tab == nil then
    return
  end

  local bufnr_set = {} ---@type table<integer, boolean>
  for _, bufnr in ipairs(bufnrs) do
    bufnr_set[bufnr] = true
  end

  for bufnr in pairs(bufnr_set) do
    local buf = state.get_buf(bufnr)
    if buf ~= nil then
      local copies = state.count_buf_copies(bufnr)
      if copies <= 1 then
        state.bufs[bufnr] = nil
        if vim.fn.buflisted(bufnr) == 1 then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end
    end
  end

  std_array.filter_inline(tab.bufnrs, function(bufnr)
    return not bufnr_set[bufnr]
  end)
  if #tab.bufnrs < 1 then
    state.tabs[tabnr_cur] = nil
    if vim.api.nvim_tabpage_is_valid(tabnr_cur) then
      vim.cmd("tabclose")
    end
  end

  local tabnr_last = state.tab_history:solid_present() ---@type integer|nil
  if tabnr_last ~= nil then
    vim.api.nvim_set_current_tabpage(tabnr_last)
  end

  state.schedule_refresh()
end

---@return nil
function M.close_current()
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local tab = state.get_current_tab()
  if tab == nil or not std_array.contains(tab.bufnrs, bufnr_cur) then
    state.schedule_refresh()
  end
  M.close({ bufnr_cur })
end

---@param step                          ?integer
---@return nil
function M.close_left(step)
  local tab, tabnr_cur = state.get_current_tab()
  if tab == nil then
    return
  end

  if #tab.bufnrs < 1 then
    state.tabs[tabnr_cur] = nil
    if vim.api.nvim_tabpage_is_valid(tabnr_cur) then
      vim.cmd("tabclose")
    end
    state.schedule_refresh()
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr_cur) or 1 ---@type integer
  local bufid_next = navigate_limit(bufid_cur, -step, #tab.bufnrs)

  local bufnrs_to_remove = {} ---@type integer[]
  for i = bufid_next, bufid_cur - 1, 1 do
    table.insert(bufnrs_to_remove, tab.bufnrs[i])
  end
  M.close(bufnrs_to_remove)
end

---@param step                          ?integer
---@return nil
function M.close_right(step)
  local tab, tabnr_cur = state.get_current_tab()
  if tab == nil then
    return
  end

  if #tab.bufnrs < 1 then
    state.tabs[tabnr_cur] = nil
    if vim.api.nvim_tabpage_is_valid(tabnr_cur) then
      vim.cmd("tabclose")
    end
    state.schedule_refresh()
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr_cur) or 1 ---@type integer
  local bufid_next = navigate_limit(bufid_cur, step, #tab.bufnrs)

  local bufnrs_to_remove = {} ---@type integer[]
  for i = bufid_cur + 1, bufid_next, 1 do
    table.insert(bufnrs_to_remove, tab.bufnrs[i])
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
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufnrs_to_remove = std_array.filter(tab.bufnrs, function(bufnr)
    return bufnr ~= bufnr_cur
  end)
  M.close(bufnrs_to_remove)
end

---@return nil
function M.close_all()
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  local bufnrs_to_remove = std_array.slice(tab.bufnrs) ---@type integer[]
  M.close(bufnrs_to_remove)
end
