---@class ghc.core.util.table
local M = {}

function M.merge_multiple_array(...)
  local result = {}
  for _, tbl in ipairs({ ... }) do
    for _, v in ipairs(tbl) do
      table.insert(result, v)
    end
  end
  return result
end

---@param arr table
function M.clone_array(arr)
  local result = {}
  for i = 1, #arr do
    result[i] = arr[i]
  end
  return result
end

return M
