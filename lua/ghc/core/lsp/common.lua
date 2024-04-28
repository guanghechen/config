---@class ghc.core.lsp.common.action
local action = {
  lsp = require("ghc.core.action.lsp"),
}

---@class ghc.core.lsp.common.util
local util = {
  lsp = require("ghc.core.util.lsp"),
}

local on_rename = function(from, to)
  local clients = util.lsp.get_clients()
  for _, client in ipairs(clients) do
    if client.supports_method("workspace/willRenameFiles") then
      local resp = client.request_sync("workspace/willRenameFiles", {
        files = {
          {
            oldUri = vim.uri_from_fname(from),
            newUri = vim.uri_from_fname(to),
          },
        },
      }, 1000, 0)
      if resp and resp.result ~= nil then
        vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
      end
    end
  end
end

local on_attach = function(client, bufnr)
  local function opts(desc)
    return { buffer = bufnr, desc = "LSP " .. desc }
  end

  -- keymap
  vim.keymap.set("n", "K", action.lsp.hover, opts("lsp: Hover"))
  vim.keymap.set("n", "gd", action.lsp.goto_definitions, opts("lsp: Goto definition"))
  vim.keymap.set("n", "gD", action.lsp.goto_declarations, opts("lsp: Goto declaration"))
  vim.keymap.set("n", "gi", action.lsp.goto_implementations, opts("lsp: Goto implementation"))
  vim.keymap.set("n", "gK", action.lsp.show_signature_help, opts("lsp: Show signature help"))
  vim.keymap.set("n", "gr", action.lsp.show_references, opts("lsp: Show references"))
  vim.keymap.set("n", "gt", action.lsp.goto_type_definitions, opts("lsp: Goto type definition"))

  -- code actions
  if util.lsp.has_support_method(bufnr, "codeLens") then
    vim.keymap.set({ "n", "v" }, "<leader>cc", action.lsp.codelens_run, opts("lsp: CodeLens"))
    vim.keymap.set("n", "<leader>cC", action.lsp.codelens_refresh, opts("lsp: Refresh & Display Codelens"))
  end
  if util.lsp.has_support_method(bufnr, "codeAction") then
    vim.keymap.set({ "n", "v" }, "<leader>ca", action.lsp.show_code_action, opts("lsp: Code action"))
    vim.keymap.set("n", "<leader>cA", action.lsp.show_code_action_source, opts("lsp: Source action"))
  end
  if util.lsp.has_support_method(bufnr, "rename") then
    vim.keymap.set("n", "<leader>cr", action.lsp.rename, opts("lsp: Rename"))
  end
end

local on_init = function(client, _)
  if client.supports_method("textDocument/semanticTokens") then
    client.server_capabilities.semanticTokensProvider = nil
  end
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem = {
  documentationFormat = { "markdown", "plaintext" },
  snippetSupport = true,
  preselectSupport = true,
  insertReplaceSupport = true,
  labelDetailsSupport = true,
  deprecatedSupport = true,
  commitCharactersSupport = true,
  tagSupport = { valueSet = { 1 } },
  resolveSupport = {
    properties = {
      "documentation",
      "detail",
      "additionalTextEdits",
    },
  },
}

return {
  on_attach = on_attach,
  on_init = on_init,
  on_rename = on_rename,
  capabilities = capabilities,
}
