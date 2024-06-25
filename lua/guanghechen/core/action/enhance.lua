---@class guanghechen.core.action.enhance
local M = {}

function M.copy_current_buffer_filepath()
  local content = fml.path.current_filepath() ---@type string
  vim.fn.setreg("+", content)
  fml.reporter.info({
    from = "enchance",
    subject = "copy_current_buffer_filepath",
    message = "Copied current buffer filepath to system clipboard!",
  })
end

return M
