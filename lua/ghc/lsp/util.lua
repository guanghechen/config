local get_clients = function(opts)
  local ret = {}
  if vim.lsp.get_clients then
    ret = vim.lsp.get_clients(opts)
  else
    ret = vim.lsp.get_active_clients(opts)
    if opts and opts.method then
      ret = vim.tbl_filter(function(client)
        return client.supports_method(opts.method, { bufnr = opts.bufnr })
      end, ret)
    end
  end
  return opts and opts.filter and vim.tbl_filter(opts.filter, ret) or ret
end

local has_support_method = function(bufnr, method)
  method = method:find("/") and method or "textDocument/" .. method
  local clients = get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    if client.supports_method(method) then
      return true
    end
  end
  return false
end

return {
  get_clients = get_clients,
  has_support_method = has_support_method,
}
