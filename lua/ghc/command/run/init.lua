local runners = {
  [".lua"] = require("ghc.command.run.lua"),
}

---@class ghc.command.run
local M = {}

---@return nil
function M.run()
  local filepath = fc.path.current_filepath()
  local extname = fc.path.extname(filepath)

  local runner = runners[extname]
  if runner ~= nil then
    runner.run(filepath)
    return
  end
end

return M
