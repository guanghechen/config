local runners = {
  [".lua"] = require("guanghechen.core.action.run.lua"),
}

---@class guanghechen.core.action.run
local M = {}

function M.run()
  local filepath = fml.path.current_filepath()
  local extname = fml.path.extname(filepath)

  local runner = runners[extname]
  if runner ~= nil then
    runner.run(filepath)
    return
  end
end

return M
