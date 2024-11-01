---@class ghc.command.run.lua
local runner = {}

---@param filepath string
---@return nil
function runner.run(filepath)
  vim.cmd("luafile " .. filepath)
end

return runner
