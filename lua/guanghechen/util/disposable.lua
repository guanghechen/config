---@class guanghechen.util.disposable
local M = {}

---@param disposables guanghechen.types.IDisposable[]
---@return nil
function M.disposeAll(disposables)
  if #disposables <= 0 then
    return
  end

  local batcher = require("guanghechen.disposable.SafeBatchHandler"):new()
  for _, disposable in ipairs(disposables) do
    batcher:run(function()
      disposable:dispose()
    end)
  end
  batcher:summary("[disposeAll] Encountered error(s) while disposing.")
end

---@param disposable any
---@return boolean
function M.isDisposable(disposable)
  return type(disposable) == "table" and type(disposable.isDisposable) == "function" and type(disposable.dispose) == "function"
end

return M
