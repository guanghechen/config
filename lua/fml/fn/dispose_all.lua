local BatchHandler = require("fml.collection.batch_handler")

---@param disposables fml.types.collection.IDisposable[]
---@return nil
local function dispose_all(disposables)
  if #disposables <= 0 then
    return
  end

  local handler = BatchHandler.new()
  for _, disposable in ipairs(disposables) do
    handler:run(function()
      disposable:dispose()
    end)
  end
  handler:summary("[fml.fn.dispose_all] Encountered error(s) while disposing.")
end

return dispose_all
