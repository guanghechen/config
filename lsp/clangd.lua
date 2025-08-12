-- https://github.com/neovim/nvim-lspconfig/blob/cc6b21ea16cc12df290152f02513a8bd0ed9d932/lsp/clangd.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#clangd

-- https://clangd.llvm.org/extensions.html#switch-between-sourceheader
local function switch_source_header(bufnr, client)
  local method_name = "textDocument/switchSourceHeader"
  ---@diagnostic disable-next-line:param-type-mismatch
  if not client or not client:supports_method(method_name) then
    return vim.notify(("method %s is not supported by any servers active on the current buffer"):format(method_name))
  end
  local params = vim.lsp.util.make_text_document_params(bufnr)
  ---@diagnostic disable-next-line:param-type-mismatch
  client:request(method_name, params, function(err, result)
    if err then
      error(tostring(err))
    end
    if not result then
      vim.notify("corresponding file cannot be determined")
      return
    end
    vim.cmd.edit(vim.uri_to_fname(result))
  end, bufnr)
end

local function symbol_info(bufnr, client)
  local method_name = "textDocument/symbolInfo"
  ---@diagnostic disable-next-line:param-type-mismatch
  if not client or not client:supports_method(method_name) then
    return vim.notify("Clangd client not found", vim.log.levels.ERROR)
  end
  local win = vim.api.nvim_get_current_win()
  local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
  ---@diagnostic disable-next-line:param-type-mismatch
  client:request(method_name, params, function(err, res)
    if err or #res == 0 then
      -- Clangd always returns an error, there is no reason to parse it
      return
    end
    local container = string.format("container: %s", res[1].containerName) ---@type string
    local name = string.format("name: %s", res[1].name) ---@type string
    vim.lsp.util.open_floating_preview({ name, container }, "", {
      height = 2,
      width = math.max(string.len(name), string.len(container)),
      focusable = false,
      focus = false,
      title = "Symbol Info",
    })
  end, bufnr)
end

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  eve.lsp.before_init(params, config)

  local capabilities = params.capabilities
  capabilities.textDocument = capabilities.textDocument or {}
  capabilities.textDocument.completion = capabilities.textDocument.completion or {}
  ---@diagnostic disable-next-line: inject-field
  capabilities.textDocument.completion.editsNearCursor = true
  ---@diagnostic disable-next-line: inject-field
  capabilities.offsetEncoding = { "utf-8", "utf-16" }
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  eve.lsp.on_attach(client, bufnr)

  vim.api.nvim_buf_create_user_command(bufnr, "LspClangdSwitchSourceHeader", function()
    switch_source_header(bufnr)
  end, { desc = "Switch between source/header" })

  vim.api.nvim_buf_create_user_command(bufnr, "LspClangdShowSymbolInfo", function()
    symbol_info()
  end, { desc = "Show symbol info" })
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  eve.lsp.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
  if config.offsetEncoding then
    client.offset_encoding = config.offsetEncoding
  end
end

return {
  capabilities = eve.lsp.get_capabilities(),
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--header-insertion=iwyu",
    "--completion-style=detailed",
    "--function-arg-placeholders",
    "--fallback-style=llvm",
  },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  init_options = {
    usePlaceholders = true,
    completeUnimported = true,
    clangdFileStatus = true,
  },
  root_markers = {
    ".clangd",
    ".clang-tidy",
    ".clang-format",
    "compile_commands.json",
    "compile_flags.txt",
    "configure.ac", -- AutoTools
    ".git",
  },
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
