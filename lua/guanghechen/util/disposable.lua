---@class guanghechen.util.disposable
local M = {}

---@param disposables guanghechen.types.IDisposable[]
---@return nil
function M.disposeAll(disposables)
  if #disposables <= 0 then
    return
  end

  local handler = require("guanghechen.disposable.SafeBatchHandler"):new()
  for _, disposable in ipairs(disposables) do
    handler:run(function()
      disposable:dispose()
    end)
  end
  handler:summary("[disposeAll] Encountered error(s) while disposing.")
end

return M
