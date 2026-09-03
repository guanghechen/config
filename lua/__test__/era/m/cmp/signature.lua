---@diagnostic disable: undefined-global

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.cmp.signature")

bootstrap.with_stl(t, {
  nvim = {
    fn = {
      augroup = function()
        return 1
      end,
    },
  },
})

local callbacks = {} ---@type table<string, function>
t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
  for _, name in ipairs(type(event) == "table" and event or { event }) do
    callbacks[name] = opts.callback
  end
  return 1
end)
t:patch_table(vim.api, "nvim_get_mode", function()
  return { mode = "i" }
end)
t:patch_table(vim.fn, "win_gettype", function()
  return ""
end)

local scheduled = {} ---@type function[]
t:patch_table(vim, "schedule", function(callback)
  scheduled[#scheduled + 1] = callback
end)

local clients = {} ---@type vim.lsp.Client[]
local requests = {} ---@type table[]
local cancellations = {} ---@type integer[]
local handler_calls = {} ---@type table[]
local conversion_calls = {} ---@type table[]
local highlights = {} ---@type table[]
local winblends = {} ---@type table[]
local valid_windows = {} ---@type table<integer, boolean>
local next_request_id = 40

t:patch_table(vim.lsp, "get_clients", function()
  return clients
end)
t:patch_table(vim.lsp.util, "make_position_params", function(_, encoding)
  return {
    textDocument = { uri = "test://" .. encoding },
    position = { line = 0, character = 0 },
  }
end)
t:patch_table(vim.lsp.util, "convert_signature_help_to_markdown_lines", function(result, filetype, triggers)
  conversion_calls[#conversion_calls + 1] = { result = result, filetype = filetype, triggers = triggers }
  return { "```" .. filetype, result.signatures[1].label, "```" }, { 1, 0, 1, 4 }
end)
t:patch_table(vim.lsp.util, "open_floating_preview", function(lines, syntax, config)
  local winnr = 100 + #handler_calls
  valid_windows[winnr] = true
  handler_calls[#handler_calls + 1] = {
    lines = lines,
    syntax = syntax,
    config = config,
    bufnr = 200 + #handler_calls,
    winnr = winnr,
  }
  local call = handler_calls[#handler_calls]
  return call.bufnr, call.winnr
end)
t:patch_table(vim.api, "nvim_get_option_value", function(name)
  return name == "filetype" and "lua" or nil
end)
t:patch_table(vim.api, "nvim_set_option_value", function(name, value, opts)
  winblends[#winblends + 1] = { name = name, value = value, opts = opts }
end)
t:patch_table(vim.api, "nvim_buf_clear_namespace", function() end)
t:patch_table(vim.hl, "range", function(bufnr, namespace, group, start, finish)
  highlights[#highlights + 1] = {
    bufnr = bufnr,
    namespace = namespace,
    group = group,
    start = start,
    finish = finish,
  }
end)
t:patch_table(vim.api, "nvim_win_is_valid", function(winnr)
  return valid_windows[winnr] == true
end)
t:patch_table(vim.api, "nvim_win_close", function(winnr)
  valid_windows[winnr] = false
end)

---@param id                            integer
---@return vim.lsp.Client
local function client(id)
  return {
    id = id,
    offset_encoding = "utf-16",
    server_capabilities = {
      signatureHelpProvider = {
        triggerCharacters = { "(" },
        retriggerCharacters = { "," },
      },
    },
    request = function(self, method, params, callback, bufnr)
      next_request_id = next_request_id + 1
      requests[#requests + 1] = {
        client = self,
        method = method,
        params = params,
        callback = callback,
        bufnr = bufnr,
        request_id = next_request_id,
      }
      return true, next_request_id
    end,
    cancel_request = function(_, request_id)
      cancellations[#cancellations + 1] = request_id
      return true
    end,
  } ---@diagnostic disable-line: return-type-mismatch
end

---@param line                          string
---@return integer
local function buffer(line)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_set_current_line(line)
  vim.api.nvim_win_set_cursor(0, { 1, #line })
  return bufnr
end

---@param request                       table
---@param result                        lsp.SignatureHelp
local function respond(request, result)
  request.callback(nil, result, {
    method = request.method,
    client_id = request.client.id,
    request_id = request.request_id,
    bufnr = request.bufnr,
    params = request.params,
  })
end

local function run_scheduled()
  assert(table.remove(scheduled, 1), "missing scheduled callback")()
end

---@param bufnr                         integer
local function cleanup(bufnr)
  callbacks.BufWipeout({ buf = bufnr })
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

local Signature = assert(loadfile("lua/era/m/cmp/signature.lua"))()
Signature.dressing()

t:test("trigger and retrigger requests carry complete protocol context", function()
  clients = { client(7) }
  requests = {}
  cancellations = {}
  handler_calls = {}
  conversion_calls = {}
  highlights = {}
  winblends = {}
  valid_windows = {}
  scheduled = {}
  local bufnr = buffer("call")
  t:patch_table(vim.v, "char", "(")

  callbacks.InsertCharPre({ buf = bufnr })
  vim.api.nvim_set_current_line("call(")
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  callbacks.TextChangedI({ buf = bufnr })
  run_scheduled()

  local first = assert(requests[1])
  t.assert_eq("textDocument/signatureHelp", first.method, "method")
  t.assert_eq(bufnr, first.bufnr, "buffer")
  t.assert_eq("test://utf-16", first.params.textDocument.uri, "client encoding")
  t.assert_eq(2, first.params.context.triggerKind, "trigger kind")
  t.assert_eq("(", first.params.context.triggerCharacter, "trigger character")
  t.assert_false(first.params.context.isRetrigger, "initial request")
  t.assert_nil(first.params.context.activeSignatureHelp, "initial active result")

  local active = {
    signatures = {
      {
        label = "call(value)",
        documentation = "hidden docs",
        parameters = { { label = "value" } },
        activeParameter = 0,
      },
    },
    activeSignature = 0,
  }
  respond(first, active)
  t.assert_eq(1, #handler_calls, "rendered response")
  t.assert_eq("rounded", handler_calls[1].config.border, "border")
  t.assert_false(handler_calls[1].config.focusable, "non-focusable")
  t.assert_eq("markdown", handler_calls[1].syntax, "syntax")
  t.assert_eq("lua", conversion_calls[1].filetype, "filetype")
  t.assert_eq("(", conversion_calls[1].triggers[1], "provider trigger")
  t.assert_nil(conversion_calls[1].result.signatures[1].documentation, "hidden documentation")
  t.assert_eq("hidden docs", active.signatures[1].documentation, "original result")
  t.assert_eq(50, winblends[1].value, "winblend")
  t.assert_eq("LspSignatureActiveParameter", highlights[1].group, "parameter highlight")

  t:patch_table(vim.v, "char", ",")
  callbacks.InsertCharPre({ buf = bufnr })
  vim.api.nvim_set_current_line("call(value,")
  vim.api.nvim_win_set_cursor(0, { 1, 11 })
  callbacks.TextChangedP({ buf = bufnr })
  run_scheduled()

  local second = assert(requests[2])
  t.assert_eq(2, second.params.context.triggerKind, "retrigger kind")
  t.assert_eq(",", second.params.context.triggerCharacter, "retrigger character")
  t.assert_true(second.params.context.isRetrigger, "retrigger state")
  t.assert_eq(active, second.params.context.activeSignatureHelp, "active result")
  t.assert_false(valid_windows[handler_calls[1].winnr], "old popup closed")
  cleanup(bufnr)
end)

t:test("toggle hides a visible signature and shows it again", function()
  clients = { client(15) }
  requests = {}
  cancellations = {}
  handler_calls = {}
  valid_windows = {}
  scheduled = {}
  local bufnr = buffer("call(")

  t.assert_true(Signature.toggle(bufnr), "show toggle")
  respond(assert(requests[1]), { signatures = { { label = "call(value)" } } })
  t.assert_true(Signature.visible(bufnr), "visible signature")

  t.assert_true(Signature.toggle(bufnr), "hide toggle")
  t.assert_false(Signature.visible(bufnr), "hidden signature")
  t.assert_eq(1, #requests, "no hidden request")

  t.assert_true(Signature.toggle(bufnr), "show again")
  t.assert_eq(2, #requests, "new request")
  cleanup(bufnr)
end)

t:test("multiple clients retain only the latest signature popup", function()
  clients = { client(16), client(17) }
  requests = {}
  cancellations = {}
  handler_calls = {}
  valid_windows = {}
  scheduled = {}
  local bufnr = buffer("call(")

  t.assert_true(Signature.show(bufnr), "explicit request")
  respond(assert(requests[1]), { signatures = { { label = "first(value)" } } })
  local first_winnr = handler_calls[1].winnr
  t.assert_true(valid_windows[first_winnr], "first popup")

  respond(assert(requests[2]), { signatures = { { label = "second(value)" } } })
  local second_winnr = handler_calls[2].winnr
  t.assert_false(valid_windows[first_winnr], "replaced popup")
  t.assert_true(valid_windows[second_winnr], "latest popup")
  t.assert_true(Signature.visible(bufnr), "owned popup")
  cleanup(bufnr)
end)

t:test("new input cancels in-flight requests and suppresses stale responses", function()
  clients = { client(8) }
  requests = {}
  cancellations = {}
  handler_calls = {}
  valid_windows = {}
  scheduled = {}
  local bufnr = buffer("call")
  t:patch_table(vim.v, "char", "(")

  callbacks.InsertCharPre({ buf = bufnr })
  vim.api.nvim_set_current_line("call(")
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  callbacks.TextChangedI({ buf = bufnr })
  run_scheduled()
  local stale = assert(requests[1])

  t:patch_table(vim.v, "char", ",")
  callbacks.InsertCharPre({ buf = bufnr })
  t.assert_eq(stale.request_id, cancellations[1], "cancelled request")
  vim.api.nvim_set_current_line("call(,")
  vim.api.nvim_win_set_cursor(0, { 1, 6 })
  callbacks.TextChangedI({ buf = bufnr })
  run_scheduled()
  local current = assert(requests[2])

  respond(stale, { signatures = { { label = "stale()" } } })
  t.assert_eq(0, #handler_calls, "stale response")
  respond(current, { signatures = { { label = "current()" } } })
  t.assert_eq(1, #handler_calls, "current response")
  cleanup(bufnr)
end)

t:test("cursor movement suppresses a delayed response", function()
  clients = { client(12) }
  requests = {}
  cancellations = {}
  handler_calls = {}
  valid_windows = {}
  scheduled = {}
  local bufnr = buffer("call(")

  t.assert_true(Signature.show(bufnr), "explicit request")
  local stale = assert(requests[1])
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  respond(stale, { signatures = { { label = "stale()" } } })

  t.assert_eq(0, #handler_calls, "moved cursor response")
  cleanup(bufnr)
end)

t:test("explicit requests and InsertLeave share the owned lifecycle", function()
  clients = { client(9) }
  requests = {}
  cancellations = {}
  handler_calls = {}
  valid_windows = {}
  scheduled = {}
  local bufnr = buffer("call(")

  t.assert_true(Signature.show(bufnr), "explicit request")
  local first = assert(requests[1])
  t.assert_eq(1, first.params.context.triggerKind, "invoked kind")
  t.assert_nil(first.params.context.triggerCharacter, "invoked character")
  respond(first, { signatures = { { label = "call(value)" } } })

  t.assert_true(Signature.show(bufnr), "repeated explicit request")
  local second = assert(requests[2])
  t.assert_true(second.params.context.isRetrigger, "explicit retrigger")
  callbacks.InsertLeave({ buf = bufnr })

  t.assert_eq(second.request_id, cancellations[#cancellations], "leave cancellation")
  t.assert_false(valid_windows[handler_calls[1].winnr], "leave popup close")
  respond(second, { signatures = { { label = "late()" } } })
  t.assert_eq(1, #handler_calls, "late response")
  cleanup(bufnr)
end)

t:test("insert entry after a trigger character requests signature help", function()
  clients = { client(10) }
  requests = {}
  cancellations = {}
  handler_calls = {}
  valid_windows = {}
  scheduled = {}
  local bufnr = buffer("call(")
  t:patch_table(vim.api, "nvim_win_get_cursor", function()
    return { 1, 5 }
  end)

  callbacks.InsertEnter({ buf = bufnr })
  run_scheduled()

  local request = assert(requests[1])
  t.assert_eq(2, request.params.context.triggerKind, "trigger kind")
  t.assert_eq("(", request.params.context.triggerCharacter, "trigger character")
  cleanup(bufnr)
end)

t:test("TextChangedI recovers mapped trigger insertions", function()
  clients = { client(13) }
  requests = {}
  cancellations = {}
  handler_calls = {}
  valid_windows = {}
  scheduled = {}
  local bufnr = buffer("call(")
  t:patch_table(vim.api, "nvim_win_get_cursor", function()
    return { 1, 5 }
  end)

  callbacks.TextChangedI({ buf = bufnr, event = "TextChangedI" })
  run_scheduled()

  local request = assert(requests[1])
  t.assert_eq(2, request.params.context.triggerKind, "trigger kind")
  t.assert_eq("(", request.params.context.triggerCharacter, "mapped trigger")
  cleanup(bufnr)
end)

t:test("autopair characters preserve the original trigger", function()
  clients = { client(14) }
  requests = {}
  cancellations = {}
  handler_calls = {}
  valid_windows = {}
  scheduled = {}
  local bufnr = buffer("call")
  t:patch_table(vim.v, "char", "(")

  callbacks.InsertCharPre({ buf = bufnr })
  t:patch_table(vim.v, "char", ")")
  callbacks.InsertCharPre({ buf = bufnr })
  vim.api.nvim_set_current_line("call()")
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  callbacks.TextChangedI({ buf = bufnr, event = "TextChangedI" })
  run_scheduled()

  local request = assert(requests[1])
  t.assert_eq("(", request.params.context.triggerCharacter, "original trigger")
  cleanup(bufnr)
end)

t:test("ordinary characters do not request signature help", function()
  clients = { client(11) }
  requests = {}
  cancellations = {}
  handler_calls = {}
  valid_windows = {}
  scheduled = {}
  local bufnr = buffer("call")
  t:patch_table(vim.v, "char", "x")

  callbacks.InsertCharPre({ buf = bufnr })
  vim.api.nvim_set_current_line("callx")
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  callbacks.TextChangedI({ buf = bufnr, event = "TextChangedI" })

  t.assert_eq(0, #scheduled, "scheduled request")
  t.assert_eq(0, #requests, "signature request")
  cleanup(bufnr)
end)

t:run()
