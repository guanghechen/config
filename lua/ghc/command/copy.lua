---@class ghc.command.copy
local M = {}

---@return nil
function M.current_buffer_filepath()
  local content = fml.path.current_filepath() ---@type string
  vim.fn.setreg("+", content)
  fml.reporter.info({
    from = "ghc.command.copy",
    subject = "current_buffer_filepath",
    message = "Copied current buffer filepath to system clipboard!",
  })
end

return M
