---@class ghc.command.copy
local M = {}

---@return nil
function M.current_buffer_filepath()
  local content = eve.path.current_filepath() ---@type string
  vim.fn.setreg("+", content)
  eve.reporter.info({
    from = "ghc.command.copy",
    subject = "current_buffer_filepath",
    message = "Copied current buffer filepath to system clipboard!",
  })
end

return M
