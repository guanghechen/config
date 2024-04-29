---@class guanghechen.disposable.util
local M = {}

---@param disposables IDisposable[]
---@return nil
function M.disposeAll(disposables)
  local handler = require("guanghechen.disposable.SafeBatchHandler"):new()
  for _, disposable in ipairs(disposables) do
    handler:run(function()
      disposable:dispose()
    end)
  end
  handler:summary("[disposeAll] Encountered error(s) while disposing.")
end

return M
