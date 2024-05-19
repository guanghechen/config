local util_path = require("guanghechen.util.path")

---@class ghc.core.action.enhance
local M = {}

function M.copy_current_buffer_filepath()
  local content = util_path.current_filepath() ---@type string
  vim.fn.setreg("+", content)
  vim.notify("Copied current buffer filepath to system clipboard!")
end

return M
