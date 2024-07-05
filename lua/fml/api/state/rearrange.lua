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
  local history = params.buf_history ---@type fml.types.collection.IHistory
  local reverse_list = {} ---@type integer[]
  local bufnr_set = {} ---@type table<integer, boolean>

  local prev_present_index = history:present_index() ---@type integer
  local next_present_index = 0 ---@type integer
  for element, idx in history:iterator() do
    table.insert(reverse_list, element)
    if prev_present_index == idx then
      next_present_index = #reverse_list
    end
  end

  next_present_index = #reverse_list - next_present_index + 1
  history:clear()
  for i = #bufnrs, 1, -1 do
    local bufnr = bufnrs[i]
    if not bufnr_set[bufnr] then
      history:push(bufnr)
      next_present_index = next_present_index + 1
    end
  end
  for i = #reverse_list, 1, -1 do
    history:push(reverse_list[i])
  end

  if next_present_index == 0 then
    local bufnr = bufnrs[1] or vim.api.nvim_list_bufs()[1] ---@type integer|nil
    if bufnr then
      history:push(bufnr)
    end
  else
    history:go(next_present_index)
  end
end

---@return nil
function M.rearrange_tab_history()
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]

  ---! Update bufnrs
  std_array.filter_inline(tabnrs, M.validate_tab)

  local history = M.tab_history ---@type fml.types.collection.IHistory
  local reverse_list = {} ---@type integer[]
  local tabnr_set = {} ---@type table<integer, boolean>

  local prev_present_index = history:present_index() ---@type integer
  local next_present_index = 0 ---@type integer
  for element, idx in history:iterator() do
    table.insert(reverse_list, element)
    if prev_present_index == idx then
      next_present_index = #reverse_list
    end
  end

  next_present_index = #reverse_list - next_present_index + 1
  history:clear()
  for i = #tabnrs, 1, -1 do
    local tabnr = tabnrs[i]
    if not tabnr_set[tabnr] then
      history:push(tabnr)
      next_present_index = next_present_index + 1
    end
  end
  for i = #reverse_list, 1, -1 do
    history:push(reverse_list[i])
  end

  if next_present_index == 0 then
    local tabnr = tabnrs[1] or vim.api.nvim_list_bufs()[1] ---@type integer|nil
    if tabnr then
      history:push(tabnr)
    end
  else
    history:go(next_present_index)
  end
end
