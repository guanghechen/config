---@class ghc.core.util.terminal
local M = {}

---@param opts 
function M.toggle_terminal(opts)
  local id = opts.id
  local cwd = opts.cwd
  LazyVim.terminal(nil, {
    id = id,
    cwd = cwd,
    border = "rounded",
    persistent = true,
  })
end

return M