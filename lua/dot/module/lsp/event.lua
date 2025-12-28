local augroup_codelens = ark.vim.fn.augroup("dot.module.lsp.event.codelens") ---@type integer

---@class dot.module.lsp.event
local M = {}

---@param from                          string
---@param to                            string
---@param rename                        ?fun(): nil
---@return nil
---@see https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/rename.lua#L51
function M.on_rename(from, to, rename)
  local changes = { files = { {
    oldUri = vim.uri_from_fname(from),
    newUri = vim.uri_from_fname(to),
  } } }

  local clients = vim.lsp.get_clients()
  for _, client in ipairs(clients) do
    if client:supports_method("workspace/willRenameFiles") then
      local resp = client:request_sync("workspace/willRenameFiles", changes, 1000, 0)
      if resp and resp.result ~= nil then
        vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
      end
    end
  end

  if rename then
    rename()
  end

  for _, client in ipairs(clients) do
    if client:supports_method("workspace/didRenameFiles") then
      client:notify("workspace/didRenameFiles", changes)
    end
  end
end

---@param from                          string
---@param to                            string
---@return boolean
function M.rename_buf(from, to)
  local from_bufnr = vim.fn.bufnr(from) ---@type integer
  if from_bufnr >= 0 then
    local to_bufnr = vim.fn.bufadd(to) ---@type integer
    vim.bo[to_bufnr].buflisted = true
    for _, win in ipairs(vim.fn.win_findbuf(from_bufnr)) do
      vim.api.nvim_win_call(win, function()
        vim.cmd("buffer " .. to_bufnr)
      end)
    end
    vim.api.nvim_buf_delete(from_bufnr, { force = true })
  end
  return true
end

---@return lsp.ClientCapabilities
function M.get_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities() ---@type lsp.ClientCapabilities
  capabilities.workspace = capabilities.workspace or {}
  capabilities.workspace.fileOperations = capabilities.workspace.fileOperations or {}
  capabilities.workspace.fileOperations.didRename = true
  capabilities.workspace.fileOperations.willRename = true
  return capabilities
end

---@param params                        lsp.InitializeParams
---@param config                        table
---@diagnostic disable-next-line: unused-local
function M.before_init(params, config)
  local has_blink, blink = pcall(require, "blink.cmp")
  if has_blink then
    params.capabilities = vim.tbl_deep_extend("force", params.capabilities, blink.get_lsp_capabilities({}, false))
  end

  local capabilities = params.capabilities ---@type lsp.ClientCapabilities
  capabilities.textDocument = capabilities.textDocument or {}
  capabilities.textDocument.completion = capabilities.textDocument.completion or {}
  capabilities.textDocument.completion.completionItem = capabilities.textDocument.completion.completionItem or {}
  capabilities.textDocument.completion.completionItem.snippetSupport = true
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
function M.on_attach(client, bufnr)
  local support_codelens = vim.b[bufnr].support_codelens or 0 ---@type integer
  local support_inlayhint = vim.b[bufnr].support_inlayhint or 0 ---@type integer
  local support_rename = vim.b[bufnr].support_rename or 0 ---@type integer
  local support_codeAction = vim.b[bufnr].support_codeAction or 0 ---@type integer
  local support_documentHighlight = vim.b[bufnr].support_documentHighlight or 0 ---@type integer
  local support_documentSymbol = vim.b[bufnr].support_documentSymbol or 0 ---@type integer
  local support_foldingRange = vim.b[bufnr].support_foldingRange or 0 ---@type integer
  local support_definition = vim.b[bufnr].support_definition or 0 ---@type integer
  local support_implementation = vim.b[bufnr].support_implementation or 0 ---@type integer
  local support_references = vim.b[bufnr].support_references or 0 ---@type integer
  local support_typeDefinition = vim.b[bufnr].support_typeDefinition or 0 ---@type integer

  if client:supports_method("textDocument/codeLens") then
    support_codelens = support_codelens + 1
  end
  if client:supports_method("textDocument/inlayHint") then
    support_inlayhint = support_inlayhint + 1
  end
  if client:supports_method("textDocument/rename") then
    support_rename = support_rename + 1
  end
  if client:supports_method("textDocument/codeAction") then
    support_codeAction = support_codeAction + 1
  end
  if client:supports_method("textDocument/documentHighlight") then
    support_documentHighlight = support_documentHighlight + 1
  end
  if client:supports_method("textDocument/documentSymbol") then
    support_documentSymbol = support_documentSymbol + 1
  end
  if client:supports_method("textDocument/foldingRange") then
    support_foldingRange = support_foldingRange + 1
  end
  if client:supports_method("textDocument/definition") then
    support_definition = support_definition + 1
  end
  if client:supports_method("textDocument/implementation") then
    support_implementation = support_implementation + 1
  end
  if client:supports_method("textDocument/references") then
    support_references = support_references + 1
  end
  if client:supports_method("textDocument/typeDefinition") then
    support_typeDefinition = support_typeDefinition + 1
  end

  vim.b[bufnr].support_codelens = support_codelens ---@type integer
  vim.b[bufnr].support_inlayhint = support_inlayhint ---@type integer
  vim.b[bufnr].support_rename = support_rename ---@type integer
  vim.b[bufnr].support_codeAction = support_codeAction ---@type integer
  vim.b[bufnr].support_documentHighlight = support_documentHighlight ---@type integer
  vim.b[bufnr].support_documentSymbol = support_documentSymbol ---@type integer
  vim.b[bufnr].support_foldingRange = support_foldingRange ---@type integer
  vim.b[bufnr].support_definition = support_definition ---@type integer
  vim.b[bufnr].support_implementation = support_implementation ---@type integer
  vim.b[bufnr].support_references = support_references ---@type integer
  vim.b[bufnr].support_typeDefinition = support_typeDefinition ---@type integer

  if vim.bo[bufnr].buftype == "" then
    -- code lens
    if support_codelens == 1 then
      local enable_code_lens = dot.context.lsp.code_lens:snapshot() ---@type boolean
      if enable_code_lens then
        vim.lsp.codelens.refresh({ bufnr = bufnr })
        vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
          buffer = bufnr,
          group = augroup_codelens,
          callback = function()
            vim.lsp.codelens.refresh({ bufnr = bufnr })
          end,
        })
      end
    end
  end

  -- inlay hints
  if support_inlayhint == 1 then
    local enable_inlay_hints = dot.context.lsp.inlay_hints:snapshot() ---@type boolean
    vim.lsp.inlay_hint.enable(enable_inlay_hints, { bufnr = bufnr })
  end

  -- highlighting: stop treesitter
  if client.server_capabilities.semanticTokensProvider then
    vim.hl.priorities.semantic_tokens = 125
  end

  if support_foldingRange == 1 then
    vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
  end

  -- illuminate
  if support_documentHighlight == 1 then
    require("dot.module.illuminate").dressing(bufnr)
  end

  ---@type ark.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "K",
      callback = function()
        vim.lsp.buf.hover({
          focus = true,
          focusable = true,
        })
      end,
      desc = "lsp: hover",
    },
    {
      modes = { "n" },
      key = "gD",
      callback = function()
        vim.cmd("normal! m'")
        vim.lsp.buf.declaration()
      end,
      desc = "lsp: goto declaration",
    },
    {
      modes = { "n" },
      key = "gK",
      callback = function()
        vim.lsp.buf.signature_help({
          focus = true,
          focusable = true,
        })
      end,
      desc = "lsp: show signature help",
    },
    {
      disabled = support_definition ~= 1,
      modes = { "n" },
      key = "gd",
      callback = function()
        vim.cmd("normal! m'")
        dot.command.definitions.lsp.goto_definitions:execute()
      end,
      desc = "lsp: goto definition",
    },
    {
      disabled = support_implementation ~= 1,
      modes = { "n" },
      key = "gi",
      callback = function()
        vim.cmd("normal! m'")
        dot.command.definitions.lsp.goto_implementations:execute()
      end,
      desc = "lsp: goto implementation",
    },
    {
      disabled = support_references ~= 1,
      modes = { "n" },
      key = "gr",
      callback = function()
        vim.cmd("normal! m'")
        dot.command.definitions.lsp.goto_references:execute()
      end,
      desc = "lsp: show references",
    },
    {
      disabled = support_typeDefinition ~= 1,
      modes = { "n" },
      key = "gt",
      callback = function()
        vim.cmd("normal! m'")
        dot.command.definitions.lsp.goto_type_definitions:execute()
      end,
      desc = "lsp: goto type definition",
    },
    {
      disabled = support_codeAction ~= 1,
      modes = { "n", "x" },
      key = "<C-a><cr>",
      aliases = { "<D-cr>", "<M-cr>" },
      callback = function()
        vim.lsp.buf.code_action()
        vim.schedule(function()
          vim.cmd("stopinsert")
        end)
      end,
      desc = "lsp: code action",
    },
    {
      disabled = support_codelens ~= 1,
      modes = { "n", "x" },
      key = "<leader>cc",
      callback = function()
        vim.lsp.codelens.run()
      end,
      desc = "lsp: codelens",
    },
    {
      disabled = support_codelens ~= 1,
      modes = { "n", "x" },
      key = "<leader>cC",
      callback = function()
        vim.lsp.codelens.refresh()
      end,
      desc = "lsp: refresh & display codelens",
    },
    {
      disabled = support_codeAction ~= 1,
      modes = { "n" },
      key = "<leader>ca",
      callback = function()
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
      desc = "lsp: source action",
    },
    {
      disabled = support_rename ~= 1,
      modes = { "n" },
      key = "<leader>cr",
      callback = function()
        vim.lsp.buf.rename(nil, { bufnr = bufnr })
        vim.schedule(function()
          vim.cmd("stopinsert")
        end)
      end,
      desc = "lsp: rename",
    },
  }
  ark.vim.fn.bindkeys(keymaps, { bufnr = bufnr })
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@diagnostic disable-next-line: unused-local
function M.on_detach(client, bufnr)
  local support_codelens = vim.b[bufnr].support_codelens or 0 ---@type integer
  local support_inlayhint = vim.b[bufnr].support_inlayhint or 0 ---@type integer
  local support_rename = vim.b[bufnr].support_rename or 0 ---@type integer
  local support_codeAction = vim.b[bufnr].support_codeAction or 0 ---@type integer
  local support_documentHighlight = vim.b[bufnr].support_documentHighlight or 0 ---@type integer
  local support_documentSymbol = vim.b[bufnr].support_documentSymbol or 0 ---@type integer
  local support_foldingRange = vim.b[bufnr].support_foldingRange or 0 ---@type integer
  local support_definition = vim.b[bufnr].support_definition or 0 ---@type integer
  local support_implementation = vim.b[bufnr].support_implementation or 0 ---@type integer
  local support_references = vim.b[bufnr].support_references or 0 ---@type integer
  local support_typeDefinition = vim.b[bufnr].support_typeDefinition or 0 ---@type integer

  if support_codelens > 0 and client:supports_method("textDocument/codeLens") then
    support_codelens = support_codelens - 1

    if support_codelens == 0 then
      vim.api.nvim_clear_autocmds({
        group = augroup_codelens,
        buffer = bufnr,
      })
    end
  end
  if support_inlayhint > 0 and client:supports_method("textDocument/inlayHint") then
    support_inlayhint = support_inlayhint - 1
  end
  if support_rename > 0 and client:supports_method("textDocument/rename") then
    support_rename = support_rename - 1
  end
  if support_codeAction > 0 and client:supports_method("textDocument/codeAction") then
    support_codeAction = support_codeAction - 1
  end
  if support_documentHighlight > 0 and client:supports_method("textDocument/documentHighlight") then
    support_documentHighlight = support_documentHighlight - 1

    if support_documentHighlight == 0 then
      require("dot.module.illuminate").undressing(bufnr)
    end
  end
  if support_documentSymbol > 0 and client:supports_method("textDocument/documentSymbol") then
    support_documentSymbol = support_documentSymbol - 1
  end
  if support_foldingRange > 0 and client:supports_method("textDocument/foldingRange") then
    support_foldingRange = support_foldingRange - 1
  end
  if support_definition > 0 and client:supports_method("textDocument/definition") then
    support_definition = support_definition - 1
  end
  if support_implementation > 0 and client:supports_method("textDocument/implementation") then
    support_implementation = support_implementation - 1
  end
  if support_references > 0 and client:supports_method("textDocument/references") then
    support_references = support_references - 1
  end
  if support_typeDefinition > 0 and client:supports_method("textDocument/typeDefinition") then
    support_typeDefinition = support_typeDefinition - 1
  end

  vim.b[bufnr].support_codelens = support_codelens ---@type integer
  vim.b[bufnr].support_inlayhint = support_inlayhint ---@type integer
  vim.b[bufnr].support_rename = support_rename ---@type integer
  vim.b[bufnr].support_codeAction = support_codeAction ---@type integer
  vim.b[bufnr].support_documentHighlight = support_documentHighlight ---@type integer
  vim.b[bufnr].support_documentSymbol = support_documentSymbol ---@type integer
  vim.b[bufnr].support_foldingRange = support_foldingRange ---@type integer
  vim.b[bufnr].support_definition = support_definition ---@type integer
  vim.b[bufnr].support_implementation = support_implementation ---@type integer
  vim.b[bufnr].support_references = support_references ---@type integer
  vim.b[bufnr].support_typeDefinition = support_typeDefinition ---@type integer
end

---@param client                        vim.lsp.Client
---@param config                        any
---@diagnostic disable-next-line: unused-local
function M.on_init(client, config) end

return M
