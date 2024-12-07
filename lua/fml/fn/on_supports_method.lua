---@type table<string, table<vim.lsp.Client, table<number, boolean>>>
local supports_method = {}

---@param client                        vim.lsp.Client
---@return nil
local function check_methods(client, bufnr)
  -- don't trigger on invalid buffers
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- don't trigger on non-listed buffers
  if not vim.bo[bufnr].buflisted then
    return
  end

  -- don't trigger on nofile buffers
  if vim.bo[bufnr].buftype == "nofile" then
    return
  end

  for method, clients in pairs(supports_method) do
    clients[client] = clients[client] or {}
    if not clients[client][bufnr] then
      if client.supports_method and client.supports_method(method, { bufnr = bufnr }) then
        clients[client][bufnr] = true
        vim.api.nvim_exec_autocmds("User", {
          pattern = "LspSupportsMethod",
          data = { client_id = client.id, buffer = bufnr, method = method },
        })
      end
    end
  end
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = eve.nvim.augroup("check_methods_on_lsp_attach"),
  callback = function(args)
    local bufnr = args.buf ---@type integer
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then
      check_methods(client, bufnr)
    end
  end,
})

vim.api.nvim_create_autocmd("User", {
  group = eve.nvim.augroup("check_methods_on_lsp_dynamic_capability"),
  pattern = "LspDynamicCapability",
  callback = function(args)
    local bufnr = args.data.buffer ---@type number
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then
      check_methods(client, bufnr)
    end
  end,
})

---@param method                        string
---@param fn                            fun(client: vim.lsp.Client, bufnr: integer): nil
local function on_supports_method(method, fn)
  supports_method[method] = supports_method[method] or setmetatable({}, { __mode = "k" })

  return vim.api.nvim_create_autocmd("User", {
    group = eve.nvim.augroup("trigger_lsp_supports_method"),
    pattern = "LspSupportsMethod",
    callback = function(args)
      local bufnr = args.data.buffer ---@type number
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and method == args.data.method then
        return fn(client, bufnr)
      end
    end,
  })
end

return on_supports_method
