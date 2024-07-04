local std_array = require("fml.std.array")

---@class fml.api.state
local M = require("fml.api.state.mod")

---@class fml.api.state.IRearrangeBufHistoryParams
---@field public buf_history            fml.types.collection.IHistory
---@field public bufnrs                 integer[]

---@param params                        fml.api.state.IRearrangeBufHistoryParams
---@return nil
function M.rearrange_buf_history(params)
  local bufnrs = params.bufnrs ---@type integer[]

  ---! Update bufnrs
  std_array.filter_inline(bufnrs, M.validate_buf)

  ---! Update buf history
  local buf_history = params.buf_history ---@type fml.types.collection.IHistory
  local buf_history_reverse_list = {} ---@type integer[]
  local buf_history_set = {} ---@type table<integer, boolean>
  local history_present_delta = 0 ---@type integer

  while true do
    local present = buf_history:present() ---@type integer|nil
    local next = buf_history:forward(1) ---@type integer|nil
    if present == next then
      break
    end
    history_present_delta = history_present_delta + 1
  end

  while true do
    local bufnr = buf_history:present() ---@type integer|nil
    if bufnr == nil then
      break
    end
    table.insert(buf_history_reverse_list, bufnr)
    buf_history_set[bufnr] = true
    buf_history:back(1)
  end

  buf_history:clear()
  for i = #bufnrs, 1, -1 do
    local bufnr = bufnrs[i]
    if not buf_history_set[bufnr] then
      buf_history:push(bufnr)
    end
  end
  for i = #buf_history_reverse_list, 1, -1 do
    buf_history:push(buf_history_reverse_list[i])
  end

  if buf_history:empty() then
    local bufnr = bufnrs[1] or vim.api.nvim_list_bufs()[1] ---@type integer|nil
    if bufnr then
      buf_history:push(bufnr)
    end
  end

  for _ = 1, history_present_delta, 1 do
    buf_history:back(1)
  end
end

---@return nil
function M.rearrange_tab_history()
  local tab_history = M.tab_history ---@type fml.types.collection.IHistory
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  local tab_history_reverse_list = {} ---@type integer[]
  local tab_history_set = {} ---@type table<integer, boolean>

  ---! Update bufnrs
  std_array.filter_inline(tabnrs, M.validate_tab)

  ---! Update buf history
  while true do
    ---! It's by design to use the :present for better performance here.
    local tabnr = tab_history:present() ---@type integer|nil
    if tabnr == nil then
      break
    end
    table.insert(tab_history_reverse_list, tabnr)
    tab_history_set[tabnr] = true
    tab_history:back(1)
  end

  tab_history:clear()
  for i = #tabnrs, 1, -1 do
    local tabnr = tabnrs[i]
    if not tab_history_set[tabnr] then
      tab_history:push(tabnr)
    end
  end
  for i = #tab_history_reverse_list, 1, -1 do
    tab_history:push(tab_history_reverse_list[i])
  end

  if tab_history:empty() then
    local tabnr = tabnrs[1] or vim.api.nvim_list_tabpages()[1] ---@type integer|nil
    if tabnr then
      tab_history:push(tabnr)
    end
  end
end
