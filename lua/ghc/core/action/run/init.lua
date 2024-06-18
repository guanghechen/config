local guanghechen = require("guanghechen")

local runners = {
  [".lua"] = require("ghc.core.action.run.lua"),
}

---@class ghc.core.action.run
local M = {}

function M.run()
  local filepath = guanghechen.util.path.current_filepath()
  local extname = guanghechen.util.path.extname(filepath)

  local runner = runners[extname]
  if runner ~= nil then
    runner.run(filepath)
    return
  end
end

return M
