---@class ghc.action.copy
local M = {}

---@return nil
function M.current_buffer_filepath()
  local content = eve.path.current_filepath() ---@type string
  vim.fn.setreg("+", content)
  eve.reporter.info({
    from = "ghc.action.copy",
    subject = "current_buffer_filepath",
    message = "Copied current buffer filepath to system clipboard!",
  })
end

return M
