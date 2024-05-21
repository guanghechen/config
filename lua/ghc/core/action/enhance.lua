local guanghechen = require("guanghechen")

---@class ghc.core.action.enhance
local M = {}

function M.copy_current_buffer_filepath()
  local content = guanghechen.util.path() ---@type string
  vim.fn.setreg("+", content)
  guanghechen.util.reporter.info({
    from = "enchance",
    subject = "copy_current_buffer_filepath",
    message = "Copied current buffer filepath to system clipboard!",
  })
end

return M
