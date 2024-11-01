local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

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
---@return string|nil
local function find_filepath(dirpath, config_filenames)
  for _, filename in ipairs(config_filenames) do
    local filepath = dirpath .. eve.path.SEP .. filename ---@type string
    if eve.fs.is_file_or_dir(filepath) == "file" then
      return filepath
    end
  end
end

---@param filepath                      string
---@param config_filenames              string[]
---@return string|nil
---@return string|nil
local function locate_lsp_root(filepath, config_filenames)
  local cwd = eve.path.cwd() ---@type string
  do
    local config_filepath = find_filepath(cwd, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return cwd, config_filepath
    end
  end

  local workspace = eve.path.workspace() ---@type string
  if cwd ~= workspace then
    local config_filepath = find_filepath(workspace, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return workspace, config_filepath
    end
  end

  local pieces = eve.path.split(filepath) ---@type string[]
  local k = #pieces - 1 ---@type integer
  while k >= 1 do
    local dirpath = table.concat(pieces, eve.path.SEP, 1, k) ---@type string
    if dirpath == cwd then
      break
    end

    local config_filepath = find_filepath(dirpath, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return dirpath, config_filepath
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
  local has_support_codeLens = eve.lsp.has_support_method(bufnr, "codeLens") ---@type boolean
  local has_support_codeAction = eve.lsp.has_support_method(bufnr, "codeAction") ---@type boolean
  local has_support_rename = eve.lsp.has_support_method(bufnr, "rename") ---@type boolean

  ---@type t.eve.IKeymap[]
  local keymaps = {
    { modes = { "n" }, key = "K", callback = vim.lsp.buf.hover, desc = "lsp: Hover" },
    { modes = { "n" }, key = "gD", callback = vim.lsp.buf.declaration, desc = "lsp: Goto declaration" },
    { modes = { "n" }, key = "gK", callback = vim.lsp.buf.signature_help, desc = "lsp: Show signature help" },
    {
      modes = { "n" },
      key = "gd",
      callback = function()
        eve.commander.execute(uuids.goto_lsp_definitions)
      end,
      desc = "lsp: Goto definition",
    },
    {
      modes = { "n" },
      key = "gi",
      callback = function()
        eve.commander.execute(uuids.goto_lsp_implementations)
      end,
      desc = "lsp: Goto implementation",
    },
    {
      modes = { "n" },
      key = "gr",
      callback = function()
        eve.commander.execute(uuids.goto_lsp_references)
      end,
      desc = "lsp: Show references",
    },
    {
      modes = { "n" },
      key = "gt",
      callback = function()
        eve.commander.execute(uuids.goto_lsp_type_definitions)
      end,
      desc = "lsp: Goto type definition",
    },
    {
      modes = { "n", "v" },
      key = "<leader>cc",
      callback = vim.lsp.codelens.run,
      desc = "lsp: CodeLens",
      active = has_support_codeLens,
    },
    {
      modes = { "n" },
      key = "<leader>cC",
      callback = vim.lsp.codelens.refresh,
      desc = "lsp: Refresh & Display Codelens",
      active = has_support_codeLens,
    },
    {
      modes = { "n", "v" },
      key = "<leader>ca",
      callback = actions.show_code_action,
      desc = "lsp: Code action",
      active = has_support_codeAction,
    },
    {
      modes = { "n", "v" },
      key = "<M-cr>",
      callback = actions.show_code_action,
      desc = "lsp: Code action",
      active = has_support_codeAction,
    },
    {
      modes = { "n" },
      key = "<leader>cA",
      callback = actions.show_code_action_source,
      desc = "lsp: Source action",
      active = has_support_codeAction,
    },
    {
      modes = { "n" },
      key = "<leader>cr",
      callback = actions.rename,
      desc = "lsp: Rename",
      active = has_support_rename,
    },
  }
  eve.nvim.bindkeys(keymaps, { bufnr = bufnr })
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
  find_filepath = find_filepath,
  locate_lsp_root = locate_lsp_root,
}
