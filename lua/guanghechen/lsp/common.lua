local actions = {
  rename = function()
    vim.lsp.buf.rename()
    vim.schedule(function()
      vim.cmd("stopinsert")
    end)
  end,

  show_code_action = function()
    vim.lsp.buf.code_action()
    vim.schedule(function()
      vim.cmd("stopinsert")
    end)
  end,

  show_code_action_source = function()
    vim.lsp.buf.code_action({
      context = {
        only = { "source" },
        diagnostics = {},
      },
    })
    vim.schedule(function()
      vim.cmd("stopinsert")
    end)
  end,
}

---@param dirpath                       string
---@param config_filenames              string[]
---@return boolean
local function check_if_lsp_root(dirpath, config_filenames)
  for _, filename in ipairs(config_filenames) do
    local filepath = dirpath .. eve.path.SEP .. filename ---@type string
    if eve.fs.is_file_or_dir(filepath) then
      return true
    end
  end
  return false
end

---@param filepath                      string
---@param config_filenames              string[]
---@return string|nil
local function locate_lsp_root(filepath, config_filenames)
  local cwd = eve.path.cwd() ---@type string

  if check_if_lsp_root(cwd, config_filenames) then
    return cwd
  end

  local workspace = eve.path.cwd() ---@type string
  if cwd ~= workspace and check_if_lsp_root(workspace, config_filenames) then
    return workspace
  end

  local pieces = eve.path.split(filepath) ---@type string[]
  local k = #pieces - 1 ---@type integer
  while k >= 1 do
    local dirpath = table.concat(pieces, eve.path.SEP, 1, k) ---@type string
    if dirpath == cwd then
      break
    end

    if check_if_lsp_root(dirpath, config_filenames) then
      return dirpath
    end
    k = k - 1
  end
end

local function on_rename(from, to)
  local clients = vim.lsp.get_clients()
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

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@diagnostic disable-next-line: unused-local
local function on_attach(client, bufnr)
  local function opts(desc)
    return { buffer = bufnr, desc = "LSP " .. desc }
  end

  -- keymap
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts("lsp: Hover"))
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts("lsp: Goto declaration"))
  vim.keymap.set("n", "gK", vim.lsp.buf.signature_help, opts("lsp: Show signature help"))
  vim.keymap.set("n", "gd", ghc.command.lsp.goto_definitions, opts("lsp: Goto definition"))
  vim.keymap.set("n", "gi", ghc.command.lsp.goto_implementations, opts("lsp: Goto implementation"))
  vim.keymap.set("n", "gr", ghc.command.lsp.goto_reference, opts("lsp: Show references"))
  vim.keymap.set("n", "gt", ghc.command.lsp.goto_type_definitions, opts("lsp: Goto type definition"))

  -- code actions
  if eve.lsp.has_support_method(bufnr, "codeLens") then
    vim.keymap.set({ "n", "v" }, "<leader>cc", vim.lsp.codelens.run, opts("lsp: CodeLens"))
    vim.keymap.set("n", "<leader>cC", vim.lsp.codelens.refresh, opts("lsp: Refresh & Display Codelens"))
  end
  if eve.lsp.has_support_method(bufnr, "codeAction") then
    vim.keymap.set({ "n", "v" }, "<leader>ca", actions.show_code_action, opts("lsp: Code action"))
    vim.keymap.set({ "n", "v" }, "<M-cr>", actions.show_code_action, opts("lsp: Code action"))
    vim.keymap.set("n", "<leader>cA", actions.show_code_action_source, opts("lsp: Source action"))
  end
  if eve.lsp.has_support_method(bufnr, "rename") then
    vim.keymap.set("n", "<leader>cr", actions.rename, opts("lsp: Rename"))
  end
end

local function on_init(client, _)
  if client.supports_method("textDocument/semanticTokens") then
    client.server_capabilities.semanticTokensProvider = nil
  end
end

local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
local capabilities = vim.tbl_deep_extend(
  "force",
  {},
  vim.lsp.protocol.make_client_capabilities(),
  has_cmp and cmp_nvim_lsp.default_capabilities() or {},
  {}
)
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
  locate_lsp_root = locate_lsp_root,
}
