---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.lsp.event" ---@type string

local Methods = vim.lsp.protocol.Methods

local augroup_codelens = stl.nvim.fn.augroup("era.m.lsp.event.codelens") ---@type integer
local augroup_foldexpr = stl.nvim.fn.augroup("era.m.lsp.event.foldexpr") ---@type integer
local augroup_inlayhint = stl.nvim.fn.augroup("era.m.lsp.event.inlayhint") ---@type integer
local augroup_keymaps = stl.nvim.fn.augroup("era.m.lsp.event.keymaps") ---@type integer

-- Servers whose document colors are hex strings. hipattern draws #RGB and #RRGGBB without a request; the
-- rest are rare or noise (LuaLS colors any 8-digit hex string, dates included), while cssls,
-- tailwindcss, dartls, ... report colors hipattern cannot recognize.
---@type table<string, true>
local HEX_COLOR_CLIENTS = {
  jsonls = true,
  lua_ls = true,
}

-- Buffers whose inlay hints are paused for typing.
local inlay_hints_paused = {} ---@type table<integer, true>
local inlay_hints_reconcile_queued = false ---@type boolean

-- Insert, Replace, Select (snippet placeholders) and the single Normal or Visual command of CTRL-O all
-- belong to typing.
---@param mode                          string
---@return boolean
local function is_typing(mode)
  return mode:find("^[iRsS\19]") ~= nil or mode:find("^ni") ~= nil or mode:find("^[vV\22]s") ~= nil
end

---@param bufnr                         integer
---@return nil
local function pause_inlay_hints(bufnr)
  if
    not inlay_hints_paused[bufnr]
    and (vim.b[bufnr].support_inlayhint or 0) > 0
    and dot.context.lsp.inlay_hints:snapshot()
  then
    inlay_hints_paused[bufnr] = true
    vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
  end
end

-- Once the mode settles, only the buffer being typed in stays paused: mappings, repeats, scroll animations
-- and snippets pass through Insert or Normal mode, and insert-mode mappings may switch buffers.
---@return nil
local function reconcile_inlay_hints()
  inlay_hints_reconcile_queued = false
  local mode = vim.api.nvim_get_mode().mode ---@type string
  -- The command line and an operator waiting for its motion end with another mode change.
  if mode:find("^c") ~= nil or mode:find("^no") ~= nil then
    return
  end
  local typing_bufnr = is_typing(mode) and vim.api.nvim_get_current_buf() or nil ---@type integer|nil
  for bufnr in pairs(inlay_hints_paused) do
    if bufnr ~= typing_bufnr then
      inlay_hints_paused[bufnr] = nil
      if
        vim.api.nvim_buf_is_valid(bufnr)
        and (vim.b[bufnr].support_inlayhint or 0) > 0
        and dot.context.lsp.inlay_hints:snapshot()
      then
        -- Enabling sends the pending changes before it requests hints, and their notification would
        -- request hints again; sent while hints are still off, they do not.
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = Methods.textDocument_inlayHint })) do
          vim.lsp._changetracking.flush(client, bufnr)
        end
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      end
    end
  end
  if typing_bufnr ~= nil then
    pause_inlay_hints(typing_bufnr)
  end
end

---@return nil
local function queue_inlay_hints_reconcile()
  if not inlay_hints_reconcile_queued then
    inlay_hints_reconcile_queued = true
    vim.schedule(reconcile_inlay_hints)
  end
end

---@type table<string, true>
local KEYMAP_METHODS = {
  ["textDocument/codeAction"] = true,
  ["textDocument/codeLens"] = true,
  ["textDocument/definition"] = true,
  ["textDocument/implementation"] = true,
  ["textDocument/references"] = true,
  ["textDocument/rename"] = true,
  ["textDocument/typeDefinition"] = true,
}

local LSP_FOLDEXPR = "v:lua.vim.lsp.foldexpr()" ---@type string

---@class era.m.lsp.event.IFoldexprState
---@field public fallback               string
---@field public windows                table<integer, string>
---@field public initially_hidden       boolean

---@type table<integer, era.m.lsp.event.IFoldexprState>
local foldexpr_states = {}

---@param state                          era.m.lsp.event.IFoldexprState
---@return nil
local function prune_invalid_windows(state)
  for winnr in pairs(state.windows) do
    if not vim.api.nvim_win_is_valid(winnr) then
      state.windows[winnr] = nil
    end
  end
end

---@param bufnr                         integer
---@return nil
local function apply_lsp_foldexpr(bufnr)
  local state = foldexpr_states[bufnr] ---@type era.m.lsp.event.IFoldexprState|nil
  if state ~= nil then
    prune_invalid_windows(state)
  end

  local visible = false ---@type boolean
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr) == bufnr then
      visible = true
      local current = vim.api.nvim_get_option_value("foldexpr", { win = winnr, scope = "local" }) ---@type string
      if current ~= LSP_FOLDEXPR then
        if state == nil then
          state = { fallback = current, windows = {}, initially_hidden = false }
          foldexpr_states[bufnr] = state
        end
        state.windows[winnr] = current
        vim.api.nvim_set_option_value("foldexpr", LSP_FOLDEXPR, { win = winnr, scope = "local" })
      end
    end
  end
  if state == nil and not visible then
    foldexpr_states[bufnr] = {
      fallback = vim.api.nvim_get_option_value("foldexpr", { scope = "global" }),
      windows = {},
      initially_hidden = true,
    }
  end
end

---@param bufnr                         integer
---@return nil
local function restore_foldexpr(bufnr)
  local state = foldexpr_states[bufnr] ---@type era.m.lsp.event.IFoldexprState|nil
  if state ~= nil then
    prune_invalid_windows(state)
  end
  local fallback = state and state.fallback or vim.api.nvim_get_option_value("foldexpr", { scope = "global" }) ---@type string

  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr) == bufnr then
      local current = vim.api.nvim_get_option_value("foldexpr", { win = winnr, scope = "local" }) ---@type string
      if current == LSP_FOLDEXPR then
        local saved = state and state.windows[winnr] or nil ---@type string|nil
        local highlighter = vim.treesitter.highlighter.active[bufnr]
        -- A hidden buffer may reach LSP attachment before its first window is configured.
        if
          state ~= nil
          and state.initially_hidden
          and (saved or fallback) == "0"
          and highlighter ~= nil
          and vim.treesitter.query.get(highlighter.tree:lang(), "folds") ~= nil
        then
          saved = "v:lua.vim.treesitter.foldexpr()"
        end
        vim.api.nvim_set_option_value("foldexpr", saved or fallback, { win = winnr, scope = "local" })
      end
      if state ~= nil then
        state.windows[winnr] = nil
      end
    end
  end

  if state ~= nil and next(state.windows) == nil then
    foldexpr_states[bufnr] = nil
  end
end

---@param bufnr                         integer
---@return nil
local function reconcile_foldexpr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    foldexpr_states[bufnr] = nil
    return
  end

  local support_folding_range = vim.b[bufnr].support_foldingRange or 0 ---@type integer
  if support_folding_range > 0 then
    apply_lsp_foldexpr(bufnr)
  else
    restore_foldexpr(bufnr)
  end
end

---@class era.m.lsp.event.IKeymap : stl.t.IKeymap
---@field public method                 ?string

---@class era.m.lsp.event.IClientKeymaps
---@field public id                     integer
---@field public name                   string
---@field public keymaps                stl.t.IKeymap[]

---@class era.m.lsp.event.IKeymapState
---@field public generic                era.m.lsp.event.IKeymap[]
---@field public clients                table<integer, era.m.lsp.event.IClientKeymaps>
---@field public bound                  table<string, { mode:string, key:string }>

---@type table<integer, era.m.lsp.event.IKeymapState>
local keymap_states = {}
local dressed = false ---@type boolean

---@class era.m.lsp.event
local M = {}

---@param from                          string
---@param to                            string
---@return boolean
function M.rename_buf(from, to)
  local from_bufnr = stl.nvim.buf.locate_bufnr(from) ---@type integer|nil
  if from_bufnr ~= nil then
    local clients = vim.lsp.get_clients({ bufnr = from_bufnr }) ---@type vim.lsp.Client[]
    for _, client in ipairs(clients) do
      vim.lsp.buf_detach_client(from_bufnr, client.id)
    end
    vim.api.nvim_buf_set_name(from_bufnr, to)
    local old_filetype = vim.api.nvim_get_option_value("filetype", { buf = from_bufnr }) ---@type string
    local filetype, on_detect = vim.filetype.match({ filename = to, buf = from_bufnr })
    filetype = filetype or ""
    if filetype ~= old_filetype then
      if on_detect ~= nil then
        on_detect(from_bufnr)
      end
      -- FileType lets enabled LSP configurations select clients for the new language.
      vim.api.nvim_set_option_value("filetype", filetype, { buf = from_bufnr })
    else
      for _, client in ipairs(clients) do
        if not vim.lsp.is_enabled(client.name) then
          vim.lsp.buf_attach_client(from_bufnr, client.id)
        end
      end
      -- Same-language moves can cross project roots; only rerun LSP config selection.
      for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ event = "FileType" })) do
        if autocmd.group_name == "nvim.lsp.enable" then
          vim.api.nvim_exec_autocmds("FileType", { group = autocmd.group, buffer = from_bufnr, modeline = false })
          break
        end
      end
    end

    -- Neovim's buffer-level save callback captures the original URI and survives client detach.
    -- Replace only that callback; resolve the URI at save time, including after later renames.
    for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ event = "BufWritePre", buffer = from_bufnr })) do
      if
        autocmd.group_name == string.format("nvim.lsp.b_%d_save", from_bufnr)
        and autocmd.desc == "vim.lsp: textDocument/willSave"
      then
        vim.api.nvim_del_autocmd(autocmd.id)
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = autocmd.group,
          buffer = from_bufnr,
          desc = "era.m.lsp: willSave with current URI",
          callback = function(event)
            local params = {
              textDocument = { uri = vim.uri_from_bufnr(event.buf) },
              reason = vim.lsp.protocol.TextDocumentSaveReason.Manual,
            }
            for _, client in ipairs(vim.lsp.get_clients({ bufnr = event.buf })) do
              if client:supports_method("textDocument/willSave") then
                client:notify("textDocument/willSave", params, event.buf)
              end
              if client:supports_method("textDocument/willSaveWaitUntil") then
                local result, err = client:request_sync("textDocument/willSaveWaitUntil", params, 1000, event.buf)
                if result and result.result then
                  vim.lsp.util.apply_text_edits(result.result, event.buf, client.offset_encoding)
                elseif err then
                  stl.reporter.error({
                    from = __module_name__,
                    subject = "willSaveWaitUntil",
                    message = vim.inspect(err),
                  })
                end
              end
            end
          end,
        })
      end
    end
  end
  return true
end

---@return lsp.ClientCapabilities
function M.get_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities() ---@type lsp.ClientCapabilities
  local workspace = capabilities.workspace --[[@as lsp.WorkspaceClientCapabilities]]
  local file_operations = workspace.fileOperations --[[@as lsp.FileOperationClientCapabilities]]
  file_operations.didRename = true
  file_operations.willRename = true

  -- Capability negotiation belongs to the LSP boundary. Loading the completion UI here would
  -- bypass its InsertEnter/CmdlineEnter lazy lifecycle.
  local text_document = capabilities.textDocument --[[@as lsp.TextDocumentClientCapabilities]]
  local completion = text_document.completion --[[@as lsp.CompletionClientCapabilities]]
  local completion_item = completion.completionItem --[[@as lsp.ClientCompletionItemOptions]]
  local resolve_support = completion_item.resolveSupport --[[@as lsp.ClientCompletionItemResolveOptions]]
  local resolve_properties = resolve_support.properties
  for _, property in ipairs({ "detail", "data" }) do
    if not vim.list_contains(resolve_properties, property) then
      resolve_properties[#resolve_properties + 1] = property
    end
  end
  completion_item.insertTextModeSupport = { valueSet = { 1 } }

  local completion_list = completion.completionList --[[@as lsp.CompletionListCapabilities]]
  local item_defaults = completion_list.itemDefaults --[[@as string[] ]]
  if not vim.list_contains(item_defaults, "commitCharacters") then
    item_defaults[#item_defaults + 1] = "commitCharacters"
  end
  completion.insertTextMode = 1

  return capabilities
end

---@param bufnr                         integer
---@return era.m.lsp.event.IKeymapState
local function get_keymap_state(bufnr)
  local state = keymap_states[bufnr]
  if state == nil then
    state = {
      generic = {},
      clients = {},
      bound = {},
    }
    keymap_states[bufnr] = state
  end
  return state
end

---@param bound                         table<string, { mode:string, key:string }>
---@param keymaps                       stl.t.IKeymap[]
---@return nil
local function track_keymaps(bound, keymaps)
  for _, keymap in ipairs(keymaps) do
    if not keymap.disabled then
      local keys = { keymap.key } ---@type string[]
      vim.list_extend(keys, keymap.aliases or {})
      for _, mode in ipairs(keymap.modes) do
        for _, key in ipairs(keys) do
          bound[mode .. "\0" .. key] = { mode = mode, key = key }
        end
      end
    end
  end
end

---@param bound                         table<string, { mode:string, key:string }>
---@param bufnr                         integer
---@return nil
local function unbind_keymaps(bound, bufnr)
  for _, keymap in pairs(bound) do
    pcall(vim.keymap.del, keymap.mode, keymap.key, { buffer = bufnr })
  end
end

---@param bufnr                         integer
---@param exclude_client_id             ?integer
---@return nil
local function reconcile_keymaps(bufnr, exclude_client_id)
  local state = keymap_states[bufnr]
  if state == nil then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    keymap_states[bufnr] = nil
    return
  end

  unbind_keymaps(state.bound, bufnr)
  state.bound = {}

  local attached_clients = {} ---@type vim.lsp.Client[]
  local attached_client_ids = {} ---@type table<integer, true>
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.id ~= exclude_client_id then
      attached_clients[#attached_clients + 1] = client
      attached_client_ids[client.id] = true
    end
  end
  if #attached_clients == 0 then
    keymap_states[bufnr] = nil
    return
  end

  local generic = {} ---@type stl.t.IKeymap[]
  for _, keymap in ipairs(state.generic) do
    if keymap.method == nil then
      generic[#generic + 1] = keymap
    else
      for _, client in ipairs(attached_clients) do
        if client:supports_method(keymap.method, bufnr) then
          generic[#generic + 1] = keymap
          break
        end
      end
    end
  end
  track_keymaps(state.bound, generic)
  stl.nvim.fn.bindkeys(generic, { bufnr = bufnr })

  local client_keymaps_list = {} ---@type era.m.lsp.event.IClientKeymaps[]
  for client_id, client_keymaps in pairs(state.clients) do
    if attached_client_ids[client_id] then
      client_keymaps_list[#client_keymaps_list + 1] = client_keymaps
    end
  end
  table.sort(client_keymaps_list, function(a, b)
    if a.name == b.name then
      return a.id < b.id
    end
    return a.name < b.name
  end)
  for _, client_keymaps in ipairs(client_keymaps_list) do
    track_keymaps(state.bound, client_keymaps.keymaps)
    stl.nvim.fn.bindkeys(client_keymaps.keymaps, { bufnr = bufnr })
  end
end

---@param registrations                 lsp.Registration[]|lsp.Unregistration[]
---@return boolean
local function changes_keymaps(registrations)
  for _, registration in ipairs(registrations) do
    if KEYMAP_METHODS[registration.method] then
      return true
    end
  end
  return false
end

---@param client_id                     integer
---@return nil
local function reconcile_client_keymaps(client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  if client == nil then
    return
  end
  for bufnr in pairs(client.attached_buffers) do
    reconcile_keymaps(bufnr)
  end
end

---@return nil
function M.dressing()
  if dressed then
    return
  end

  local register_capability = assert(vim.lsp.handlers[Methods.client_registerCapability])
  local unregister_capability = assert(vim.lsp.handlers[Methods.client_unregisterCapability])

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = augroup_keymaps,
    callback = function(args)
      keymap_states[args.buf] = nil
    end,
  })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup_foldexpr,
    callback = function(args)
      reconcile_foldexpr(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = augroup_foldexpr,
    callback = function(args)
      foldexpr_states[args.buf] = nil
    end,
  })
  -- Inlay hints are requested and redrawn after every change, so they pause in the buffer being typed in
  -- and resume once the mode settles outside typing. CTRL-C skips InsertLeave, hence ModeChanged.
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = augroup_inlayhint,
    callback = function(args)
      if not is_typing(args.match:match(":(.*)$") or "") then
        if next(inlay_hints_paused) ~= nil then
          queue_inlay_hints_reconcile()
        end
      elseif not inlay_hints_paused[args.buf] then
        -- A typed key pauses at once, before a change made on the way in (cc, o) is notified and requests
        -- hints. Pending keys (a mapping, a repeat, a macro) may only pass through and wait for the mode
        -- to settle.
        if vim.fn.state("m") == "" then
          pause_inlay_hints(args.buf)
        else
          queue_inlay_hints_reconcile()
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = augroup_inlayhint,
    callback = function()
      if next(inlay_hints_paused) ~= nil or is_typing(vim.api.nvim_get_mode().mode) then
        queue_inlay_hints_reconcile()
      end
    end,
  })

  vim.lsp.handlers[Methods.client_registerCapability] = function(err, params, ctx, config)
    local result = register_capability(err, params, ctx, config) ---@type any
    if changes_keymaps(params.registrations or {}) then
      reconcile_client_keymaps(ctx.client_id)
    end
    return result
  end
  vim.lsp.handlers[Methods.client_unregisterCapability] = function(err, params, ctx, config)
    local result = unregister_capability(err, params, ctx, config) ---@type any
    if changes_keymaps(params.unregisterations or {}) then
      reconcile_client_keymaps(ctx.client_id)
    end
    return result
  end

  dressed = true
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@param keymaps                       stl.t.IKeymap[]
---@return nil
function M.bindkeys(client, bufnr, keymaps)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local state = get_keymap_state(bufnr)
  state.clients[client.id] = {
    id = client.id,
    name = client.name,
    keymaps = keymaps,
  }
  reconcile_keymaps(bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
function M.on_attach(client, bufnr)
  local support_codelens = vim.b[bufnr].support_codelens or 0 ---@type integer
  local support_inlayhint = vim.b[bufnr].support_inlayhint or 0 ---@type integer
  local support_documentHighlight = vim.b[bufnr].support_documentHighlight or 0 ---@type integer
  local support_documentSymbol = vim.b[bufnr].support_documentSymbol or 0 ---@type integer
  local support_foldingRange = vim.b[bufnr].support_foldingRange or 0 ---@type integer

  if client:supports_method("textDocument/codeLens") then
    support_codelens = support_codelens + 1
  end
  if client:supports_method("textDocument/inlayHint") then
    support_inlayhint = support_inlayhint + 1
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

  vim.b[bufnr].support_codelens = support_codelens ---@type integer
  vim.b[bufnr].support_inlayhint = support_inlayhint ---@type integer
  vim.b[bufnr].support_documentHighlight = support_documentHighlight ---@type integer
  vim.b[bufnr].support_documentSymbol = support_documentSymbol ---@type integer
  vim.b[bufnr].support_foldingRange = support_foldingRange ---@type integer

  if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "" then
    -- code lens
    if support_codelens == 1 then
      local enable_code_lens = dot.context.lsp.code_lens:snapshot() ---@type boolean
      if enable_code_lens then
        vim.lsp.codelens.enable(true, { bufnr = bufnr })
        vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
          buffer = bufnr,
          group = augroup_codelens,
          callback = function()
            vim.lsp.codelens.enable(true, { bufnr = bufnr })
          end,
        })
      end
    end
  end

  -- inlay hints
  if support_inlayhint == 1 then
    local enable_inlay_hints = dot.context.lsp.inlay_hints:snapshot() ---@type boolean
    -- A client attaching while its buffer is being typed in starts paused like the rest of the session.
    if enable_inlay_hints and bufnr == vim.api.nvim_get_current_buf() and is_typing(vim.api.nvim_get_mode().mode) then
      inlay_hints_paused[bufnr] = true
      enable_inlay_hints = false
    end
    vim.lsp.inlay_hint.enable(enable_inlay_hints, { bufnr = bufnr })
  end

  -- document colors: these servers only report hex literals that hipattern already renders, and every
  -- change would request them again.
  if HEX_COLOR_CLIENTS[client.name] and client:supports_method("textDocument/documentColor") then
    vim.lsp.document_color.enable(false, { bufnr = bufnr, client_id = client.id })
  end

  -- highlighting: stop treesitter
  if client.server_capabilities.semanticTokensProvider then
    vim.hl.priorities.semantic_tokens = 125
  end

  if support_foldingRange == 1 then
    apply_lsp_foldexpr(bufnr)
  end

  -- illuminate
  if support_documentHighlight == 1 then
    era.m.lsp.illuminate.dressing(bufnr)
  end

  ---@type era.m.lsp.event.IKeymap[]
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
      method = "textDocument/definition",
      modes = { "n" },
      key = "gd",
      callback = function()
        vim.cmd("normal! m'")
        dot.command.definitions.lsp.goto_definitions:execute()
      end,
      desc = "lsp: goto definition",
    },
    {
      method = "textDocument/implementation",
      modes = { "n" },
      key = "gi",
      callback = function()
        vim.cmd("normal! m'")
        dot.command.definitions.lsp.goto_implementations:execute()
      end,
      desc = "lsp: goto implementation",
    },
    {
      method = "textDocument/references",
      modes = { "n" },
      key = "gr",
      callback = function()
        vim.cmd("normal! m'")
        dot.command.definitions.lsp.goto_references:execute()
      end,
      desc = "lsp: show references",
    },
    {
      method = "textDocument/typeDefinition",
      modes = { "n" },
      key = "gt",
      callback = function()
        vim.cmd("normal! m'")
        dot.command.definitions.lsp.goto_type_definitions:execute()
      end,
      desc = "lsp: goto type definition",
    },
    {
      method = "textDocument/codeAction",
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
      method = "textDocument/codeLens",
      modes = { "n", "x" },
      key = "<leader>cc",
      callback = function()
        vim.lsp.codelens.run()
      end,
      desc = "lsp: codelens",
    },
    {
      method = "textDocument/codeLens",
      modes = { "n", "x" },
      key = "<leader>cC",
      callback = function()
        vim.lsp.codelens.enable(true, { bufnr = bufnr })
      end,
      desc = "lsp: refresh & display codelens",
    },
    {
      method = "textDocument/codeAction",
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
      method = "textDocument/rename",
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
  local state = get_keymap_state(bufnr)
  state.generic = keymaps
  reconcile_keymaps(bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
function M.on_detach(client, bufnr)
  local support_codelens = vim.b[bufnr].support_codelens or 0 ---@type integer
  local support_inlayhint = vim.b[bufnr].support_inlayhint or 0 ---@type integer
  local support_documentHighlight = vim.b[bufnr].support_documentHighlight or 0 ---@type integer
  local support_documentSymbol = vim.b[bufnr].support_documentSymbol or 0 ---@type integer
  local support_foldingRange = vim.b[bufnr].support_foldingRange or 0 ---@type integer

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
  if support_documentHighlight > 0 and client:supports_method("textDocument/documentHighlight") then
    support_documentHighlight = support_documentHighlight - 1

    if support_documentHighlight == 0 then
      era.m.lsp.illuminate.undressing(bufnr)
    end
  end
  if support_documentSymbol > 0 and client:supports_method("textDocument/documentSymbol") then
    support_documentSymbol = support_documentSymbol - 1
  end
  if support_foldingRange > 0 and client:supports_method("textDocument/foldingRange") then
    support_foldingRange = support_foldingRange - 1
    if support_foldingRange == 0 then
      restore_foldexpr(bufnr)
    end
  end

  vim.b[bufnr].support_codelens = support_codelens ---@type integer
  vim.b[bufnr].support_inlayhint = support_inlayhint ---@type integer
  vim.b[bufnr].support_documentHighlight = support_documentHighlight ---@type integer
  vim.b[bufnr].support_documentSymbol = support_documentSymbol ---@type integer
  vim.b[bufnr].support_foldingRange = support_foldingRange ---@type integer

  local state = keymap_states[bufnr]
  if state ~= nil then
    state.clients[client.id] = nil
    reconcile_keymaps(bufnr, client.id)
  end
end

return M
