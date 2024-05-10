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

return M
