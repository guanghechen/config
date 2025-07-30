local __module_name__ = "fml.action.lsp.server" ---@type string

---@class fml.action.lsp
local M = {}

---@return nil
function M.restart()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local clients = vim.lsp.get_clients({ bufnr = bufnr }) ---@type vim.lsp.Client[]

  std.reporter.info({
    from = __module_name__,
    subject = "restart",
  })

  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id)
  end

  vim.defer_fn(function()
    vim.cmd.edit()
  end, 100)
end

return M
