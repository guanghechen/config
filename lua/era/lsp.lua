local __module_name__ = "era.lsp"

local Methods = vim.lsp.protocol.Methods
local augroup_codelens = ark.nvim.augroup("era.lsp.codelens") ---@type integer
local augroup_illuminate = ark.nvim.augroup("era.lsp.illuminate") ---@type integer

---@class era.t.ISymbolPos
---@field public line                   integer
---@field public character              integer

---! Check if cursor is within range
---@param cursor                        era.t.ISymbolPos
---@param range                         { start: era.t.ISymbolPos, end: era.t.ISymbolPos }
---@return boolean
local function is_within_range(cursor, range)
  local start = range.start ---@type era.t.ISymbolPos
  local finish = range["end"] ---@type era.t.ISymbolPos
  return (cursor.line > start.line or (cursor.line == start.line and cursor.character >= start.character))
    and (cursor.line < finish.line or (cursor.line == finish.line and cursor.character <= finish.character))
end

---@class era.lsp
local M = {}

---! Find the symbol path recursively
---@param cursor                        era.t.ISymbolPos
---@param symbols                       any[]|nil
---@return any[]|nil
function M.find_symbol_path(cursor, symbols)
  if symbols == nil then
    return
  end

  for _, symbol in ipairs(symbols) do
    if symbol.location then
      local range = symbol.location.range
      if is_within_range(cursor, range) then
        return { symbol }
      end
    elseif symbol.range then
      local range = symbol.range
      if is_within_range(cursor, range) then
        local path = { symbol }
        if symbol.children then
          local child_path = M.find_symbol_path(cursor, symbol.children)
          if child_path then
            for _, child_symbol in ipairs(child_path) do
              path[#path + 1] = child_symbol
            end
          end
        end
        return path
      end
    end
  end
  return nil
end

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
    if client:supports_method(Methods.workspace_willRenameFiles) then
      local resp = client:request_sync(Methods.workspace_willRenameFiles, changes, 1000, 0)
      if resp and resp.result ~= nil then
        vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
      end
    end
  end

  if rename then
    rename()
  end

  for _, client in ipairs(clients) do
    if client:supports_method(Methods.workspace_didRenameFiles) then
      client:notify(Methods.workspace_didRenameFiles, changes)
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

---@param dirpath                       string
---@param config_filenames              string[]
---@return string|nil
function M.find_filepath(dirpath, config_filenames)
  for _, filename in ipairs(config_filenames) do
    local filepath = dirpath .. ark.env.PATH_SEP .. filename ---@type string
    if yoz.path.is_exist_file(filepath) then
      return filepath
    end
  end
end

---@param filepath                      string
---@param config_filenames              string[]
---@return string|nil
---@return string|nil
function M.locate_lsp_root(filepath, config_filenames)
  local cwd = dot.path.cwd() ---@type string
  do
    local config_filepath = M.find_filepath(cwd, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return cwd, config_filepath
    end
  end

  local workspace = dot.path.workspace() ---@type string
  if cwd ~= workspace then
    local config_filepath = M.find_filepath(workspace, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return workspace, config_filepath
    end
  end

  local pieces = yoz.path.split(filepath, false) ---@type string[]
  local k = #pieces - 1 ---@type integer
  while k >= 1 do
    local dirpath = table.concat(pieces, ark.env.PATH_SEP, 1, k) ---@type string
    if dirpath == cwd then
      break
    end

    local config_filepath = M.find_filepath(dirpath, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return dirpath, config_filepath
    end
    k = k - 1
  end
end

---@param bin                           string
---@param silent                        ?boolean
---@return string|nil
function M.locate_mason_bin_path(bin, silent)
  local root = vim.env.MASON or (ark.env.HOME_NVIM_DATA .. ark.env.PATH_SEP .. "mason")
  local resolved_binname = ark.env.IS_WIN and not bin:match("%.cmd$") and (bin .. ".cmd") or bin ---@type string
  local filepath = dot.path.normalize(root .. "/bin/" .. resolved_binname) ---@type string

  if yoz.path.is_exist_file(filepath) then
    return filepath
  end

  if not silent then
    ark.reporter.warn({
      from = __module_name__,
      subject = "locate_mason_bin_path",
      message = string.format(
        "Mason binary not found for **%s**:\\n- You may need to install the package via Mason.",
        resolved_binname,
        filepath
      ),
      details = {
        root = root,
        original_binname = bin,
        resolved_binname = resolved_binname,
        filepath = filepath,
      },
    })
  end

  return nil
end

---@param pkg                           string
---@param pkg_path                      string
---@param silent                        ?boolean
---@return string|nil
function M.locate_mason_pkg_path(pkg, pkg_path, silent)
  pcall(require, "mason") -- make sure Mason is loaded. Will fail when generating docs
  local root = vim.env.MASON or (ark.env.HOME_NVIM_DATA .. ark.env.PATH_SEP .. "mason")
  local filepath = root .. "/packages/" .. pkg .. "/" .. pkg_path

  if not vim.uv.fs_stat(filepath) and not ark.env.IS_HEADLESS then
    if not silent then
      ark.reporter.warn({
        from = __module_name__,
        subject = "locate_mason_pkg_path",
        message = string.format(
          "Mason package path not found for **%s**:\n- `%s`\nYou may need to force update the package.",
          pkg,
          pkg_path
        ),
      })
    end
    return nil
  end

  return filepath
end

----------------------------------------------------------------------------------------------------

---@param filepath                      string
---@param offset                        integer
---@param highlights                    ark.t.IHighlightInline[]
---@return string
function M.calc_diagnostic_info(filepath, offset, highlights)
  local bufnr = dot.buf.locate_bufnr(filepath) ---@type integer|nil
  if bufnr == nil or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return ""
  end

  local text = "" ---@type string

  local count_error = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })
  if count_error > 0 then
    local part = " " .. dot.icon.diagnostic.Error_alt .. " " .. count_error ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_error" }
    offset = offset_next
  end

  local count_warn = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.WARN })
  if count_warn > 0 then
    local part = " " .. dot.icon.diagnostic.Warning_alt .. " " .. count_warn ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_warn" }
    offset = offset_next
  end

  local count_hint = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.HINT })
  if count_hint > 0 then
    local part = " " .. dot.icon.diagnostic.Hint_alt .. " " .. count_hint ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_hint" }
    offset = offset_next
  end

  local count_info = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.INFO })
  if count_info > 0 then
    local part = " " .. dot.icon.diagnostic.Information_alt .. " " .. count_info ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_info" }
    offset = offset_next
  end

  return text
end

----------------------------------------------------------------------------------------------------

---@return lsp.ClientCapabilities
M.get_capabilities = function()
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

  if client:supports_method(Methods.textDocument_codeLens) then
    support_codelens = support_codelens + 1
  end
  if client:supports_method(Methods.textDocument_inlayHint) then
    support_inlayhint = support_inlayhint + 1
  end
  if client:supports_method(Methods.textDocument_rename) then
    support_rename = support_rename + 1
  end
  if client:supports_method(Methods.textDocument_codeAction) then
    support_codeAction = support_codeAction + 1
  end
  if client:supports_method(Methods.textDocument_documentHighlight) then
    support_documentHighlight = support_documentHighlight + 1
  end
  if client:supports_method(Methods.textDocument_documentSymbol) then
    support_documentSymbol = support_documentSymbol + 1
  end
  if client:supports_method(Methods.textDocument_foldingRange) then
    support_foldingRange = support_foldingRange + 1
  end
  if client:supports_method(Methods.textDocument_definition) then
    support_definition = support_definition + 1
  end
  if client:supports_method(Methods.textDocument_implementation) then
    support_implementation = support_implementation + 1
  end
  if client:supports_method(Methods.textDocument_references) then
    support_references = support_references + 1
  end
  if client:supports_method(Methods.textDocument_typeDefinition) then
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
    local enabled = dot.context.flight.dressing_illumniate:snapshot() ---@type boolean
    if enabled then
      vim.api.nvim_create_autocmd({ "CursorHold" }, {
        group = augroup_illuminate,
        buffer = bufnr,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = augroup_illuminate,
        buffer = bufnr,
        callback = vim.lsp.buf.clear_references,
      })
    end
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
        era.command.execute(era.command.definitions.lsp.goto_definitions.uuid)
      end,
      desc = "lsp: goto definition",
    },
    {
      disabled = support_implementation ~= 1,
      modes = { "n" },
      key = "gi",
      callback = function()
        vim.cmd("normal! m'")
        era.command.execute(era.command.definitions.lsp.goto_implementations.uuid)
      end,
      desc = "lsp: goto implementation",
    },
    {
      disabled = support_references ~= 1,
      modes = { "n" },
      key = "gr",
      callback = function()
        vim.cmd("normal! m'")
        era.command.execute(era.command.definitions.lsp.goto_references.uuid)
      end,
      desc = "lsp: show references",
    },
    {
      disabled = support_typeDefinition ~= 1,
      modes = { "n" },
      key = "gt",
      callback = function()
        vim.cmd("normal! m'")
        era.command.execute(era.command.definitions.lsp.goto_type_definitions.uuid)
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
  ark.nvim.bindkeys(keymaps, { bufnr = bufnr })
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

  if support_codelens > 0 and client:supports_method(Methods.textDocument_codeLens) then
    support_codelens = support_codelens - 1

    if support_codelens == 0 then
      vim.api.nvim_clear_autocmds({
        group = augroup_codelens, -- You need to define this augroup
        buffer = bufnr,
      })
    end
  end
  if support_inlayhint > 0 and client:supports_method(Methods.textDocument_inlayHint) then
    support_inlayhint = support_inlayhint - 1
  end
  if support_rename > 0 and client:supports_method(Methods.textDocument_rename) then
    support_rename = support_rename - 1
  end
  if support_codeAction > 0 and client:supports_method(Methods.textDocument_codeAction) then
    support_codeAction = support_codeAction - 1
  end
  if support_documentHighlight > 0 and client:supports_method(Methods.textDocument_documentHighlight) then
    support_documentHighlight = support_documentHighlight - 1

    if support_documentHighlight == 0 then
      vim.lsp.buf.clear_references()
      vim.api.nvim_clear_autocmds({
        group = augroup_illuminate,
        buffer = bufnr,
      })
    end
  end
  if support_documentSymbol > 0 and client:supports_method(Methods.textDocument_documentSymbol) then
    support_documentSymbol = support_documentSymbol - 1
  end
  if support_foldingRange > 0 and client:supports_method(Methods.textDocument_foldingRange) then
    support_foldingRange = support_foldingRange - 1
  end
  if support_definition > 0 and client:supports_method(Methods.textDocument_definition) then
    support_definition = support_definition - 1
  end
  if support_implementation > 0 and client:supports_method(Methods.textDocument_implementation) then
    support_implementation = support_implementation - 1
  end
  if support_references > 0 and client:supports_method(Methods.textDocument_references) then
    support_references = support_references - 1
  end
  if support_typeDefinition > 0 and client:supports_method(Methods.textDocument_typeDefinition) then
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
