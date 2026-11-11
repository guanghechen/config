local harness = require("__test__.support.harness")
local runtime = require("__test__.support.cmp.runtime")
local fixture = require("__test__.support.cmp.fixture")
runtime.setup()
local t = harness.new()
local Lsp = require("era.keystroke.cmp.source.lsp")

t:test("completion-list defaults preserve data and insert ranges", function()
  local context = runtime.context("foo")
  local response = Lsp.response(context, { id = 10, offset_encoding = "utf-16" }, {
    isIncomplete = true,
    itemDefaults = {
      insertTextFormat = 2,
      data = { import = true },
      editRange = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
    },
    items = { { label = "foo", textEditText = "foo($0)" } },
  })
  t.assert_true(response.incomplete, "incomplete result")
  t.assert_eq("foo($0)", response.items[1].raw.textEdit.newText, "default edit")
  t.assert_true(response.items[1].raw.data.import, "resolve payload")
  t.assert_eq(2, response.items[1].raw.insertTextFormat, "snippet format")
end)

t:test("null LSP responses are retryable during server initialization", function()
  local response = Lsp.response(runtime.context("obj."), { id = 10, offset_encoding = "utf-16" }, nil)
  t.assert_true(response.incomplete, "null results must not poison the cache")
  t.assert_eq(0, #response.items, "no initial candidates")
end)

t:test("normalizing LSP defaults never mutates the server response", function()
  local raw = { label = "foo", insertTextMode = vim.NIL }
  local range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } }
  local response = Lsp.response(runtime.context("foo"), { id = 10, offset_encoding = "utf-16" }, {
    items = { raw },
    itemDefaults = { data = { token = "fixture" }, editRange = range },
  })
  t.assert_eq(nil, raw.data, "original resolve data")
  t.assert_eq(nil, raw.textEdit, "original edit range")
  t.assert_eq(vim.NIL, raw.insertTextMode, "original JSON null")
  t.assert_eq("fixture", response.items[1].raw.data.token, "normalized data")
  t.assert_eq(nil, response.items[1].raw.insertTextMode, "null is removed")
  t.assert_eq("foo", response.items[1].raw.textEdit.newText, "default edit is materialized")
end)

t:test("nullable completion fields fall back without changing opaque payloads", function()
  fixture.buffer(t, { "al" })
  local context = runtime.context("al")
  local client = { id = 10, name = "fixture", offset_encoding = "utf-16" }
  local raw = vim.json.decode([[
    {"label":"alpha","insertText":null,"textEdit":null,"filterText":null,"sortText":null,
     "detail":null,"labelDetails":{"description":null},"insertTextFormat":null,
     "additionalTextEdits":null,"data":{"value":null,"list":[null]},"extension":null,
     "command":{"title":"run","command":"fixture","arguments":[null]}}
  ]])
  local original = vim.deepcopy(raw)
  local item = Lsp.response(context, client, { raw }).items[1]
  local plan = assert(require("era.keystroke.cmp.edit").plan(item, context))
  t.assert_eq("alpha", plan.main.newText, "label supplies the missing insertion")
  local plain = Lsp.response(context, client, { { label = "alpha" } }).items[1]
  t.assert_eq(plain.frecency_key, item.frecency_key, "null presentation fields do not change history")
  t.assert_eq(raw.data, item.raw.data, "opaque data is retained without copying")
  t.assert_eq(vim.NIL, item.raw.data.value, "nested null")
  t.assert_eq(vim.NIL, item.raw.data.list[1], "array null")
  t.assert_eq(vim.NIL, item.raw.command.arguments[1], "command argument null")
  t.assert_eq(vim.NIL, item.raw.extension, "unknown fields remain opaque")
  t.assert_same(original, raw, "source payload is immutable")
  local Rank = require("era.keystroke.cmp.rank")
  t.assert_eq(item, Rank.filter(context, Rank.prepare({ item }))[1], "candidate remains matchable")
end)

t:test("nullable completion edits inherit defaults and retain insert ranges", function()
  fixture.buffer(t, { "alTail" })
  local context = runtime.context("alTail", 2)
  local client = { id = 10, name = "fixture", offset_encoding = "utf-16" }
  local insert = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 2 } }
  local replace = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 6 } }
  for _, edit_range in ipairs({ insert, { insert = insert, replace = replace } }) do
    local raw = { label = "alpha", insertText = vim.NIL, textEditText = vim.NIL, textEdit = vim.NIL, data = vim.NIL }
    local item = Lsp.response(context, client, {
      items = { raw },
      itemDefaults = { editRange = edit_range, insertTextFormat = vim.NIL, data = { inherited = true } },
    }).items[1]
    local plan = assert(require("era.keystroke.cmp.edit").plan(item, context))
    t.assert_eq("alpha", plan.main.newText, "null textEditText falls back to label")
    t.assert_eq(2, plan.main.range["end"].character, "suffix remains outside the edit")
    t.assert_eq(vim.NIL, item.raw.data, "explicit opaque null overrides the default")
    t.assert_eq(vim.NIL, raw.textEdit, "source edit is unchanged")
  end
  local raw = { label = "alpha", textEdit = { newText = "alpha", range = vim.NIL, insert = insert, replace = replace } }
  local item = Lsp.response(context, client, { raw }).items[1]
  t.assert_eq(2, assert(require("era.keystroke.cmp.edit").plan(item, context)).main.range["end"].character)
  t.assert_eq(vim.NIL, raw.textEdit.range, "nested source fields are unchanged")
  local invalid = Lsp.response(context, client, {
    items = { { label = "alpha" } },
    itemDefaults = { editRange = { insert = vim.NIL, replace = replace } },
  })
  t.assert_eq(0, #invalid.items, "a missing required insert range is rejected without indexing null")
end)

t:test("resolve nulls preserve original edits and explicit opaque data", function()
  fixture.buffer(t, { "al" })
  local context = runtime.context("al")
  local raw = { label = "alpha", insertText = "alphabet", data = { token = vim.NIL } }
  local resolved = { label = "alpha", insertText = vim.NIL, textEdit = vim.NIL, detail = vim.NIL, data = vim.NIL }
  local client = {
    id = 10,
    name = "fixture",
    offset_encoding = "utf-16",
    server_capabilities = { completionProvider = { resolveProvider = true } },
    request = function(_, method, params, callback)
      t.assert_eq("completionItem/resolve", method)
      t.assert_eq(raw.data, params.data, "resolve request retains opaque data")
      callback(nil, resolved)
      return true, 1
    end,
    cancel_request = function() end,
  }
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)
  local item = Lsp.response(context, client, { raw }).items[1]
  t.assert_eq(raw, item.raw, "ordinary candidates require no payload copy")
  local result
  t:defer(assert(Lsp.resolve(item, function(value)
    result = value
  end)))
  t.assert_eq("alphabet", assert(require("era.keystroke.cmp.edit").plan(item, context, result)).main.newText)
  t.assert_eq(vim.NIL, result.data, "resolved opaque null replaces the original data")
  t.assert_eq(vim.NIL, resolved.insertText, "resolve response is immutable")
  t.assert_eq("alphabet", raw.insertText, "original completion is immutable")
end)

t:test("LuaLS resolve promotes its leading signature without changing server payloads", function()
  local raw = { label = "normalize(value)", insertText = "normalize(${1:value})", insertTextFormat = 2 }
  local documentation = {
    kind = "markdown",
    value = "```lua\nfunction normalize(value: string)\n  -> string\n```\n\n---\n\nParameter documentation.",
  }
  local resolved = { detail = "function", documentation = documentation, data = { token = vim.NIL } }
  local original = vim.deepcopy(resolved)
  local client = {
    id = 10,
    name = "lua_ls",
    offset_encoding = "utf-16",
    server_capabilities = { completionProvider = { resolveProvider = true } },
    request = function(_, _, _, callback)
      callback(nil, resolved)
      return true, 1
    end,
    cancel_request = function() end,
  }
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)
  local item = Lsp.response(runtime.context("nor"), client, { raw }).items[1]
  local result
  t:defer(assert(Lsp.resolve(item, function(value)
    result = value
  end)))
  t.assert_eq("function normalize(value: string)\n  -> string", result.detail)
  t.assert_eq("\n\n---\n\nParameter documentation.", result.documentation.value)
  t.assert_eq(raw.insertText, result.insertText, "insertion semantics are retained")
  t.assert_eq(resolved.data, result.data, "opaque resolve data is shared")
  t.assert_same(original, resolved, "resolve response is immutable")
  t.assert_eq(nil, raw.detail, "original completion is immutable")

  client.server_capabilities.completionProvider.resolveProvider = false
  item.raw = vim.tbl_extend("force", {}, raw, resolved)
  Lsp.resolve(item, function(value)
    result = value
  end)
  t.assert_eq(
    "function normalize(value: string)\n  -> string",
    result.detail,
    "inline documentation uses the same path"
  )
  t.assert_eq(documentation, item.raw.documentation, "inline payload remains unchanged")
end)

t:test("LuaLS signature projection leaves unrelated or incomplete documentation alone", function()
  local signature = "```lua\nfunction normalize(value: string)\n```"
  local client = {
    id = 10,
    name = "lua_ls",
    offset_encoding = "utf-16",
    server_capabilities = { completionProvider = {} },
  }
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)
  for _, documentation in ipairs({
    signature,
    { kind = "plaintext", value = signature },
    { kind = "markdown", value = "    " .. signature },
    { kind = "markdown", value = "Explanation.\n\n" .. signature },
    { kind = "markdown", value = "```lua\nfunction normalize(value: string)" },
    { kind = "markdown", value = signature .. "unclosed fence" },
    { kind = "markdown", value = "```lua\nprint(value)\n```" },
    { kind = "markdown", value = vim.NIL },
  }) do
    local raw = { label = "normalize", detail = "function", documentation = documentation }
    local item = Lsp.response(runtime.context("nor"), client, { raw }).items[1]
    Lsp.resolve(item, function(result)
      t.assert_eq(raw, result, "unchanged documentation does not allocate a projection")
    end)
  end
  for _, detail in ipairs({ "", vim.NIL }) do
    local item = Lsp.response(runtime.context("nor"), client, {
      { label = "normalize", detail = detail, documentation = { kind = "markdown", value = signature } },
    }).items[1]
    Lsp.resolve(item, function(result)
      t.assert_eq(signature, result.documentation.value, "absent details cannot identify a signature")
    end)
  end
  client.name = "another_server"
  local raw = { label = "normalize", detail = "function", documentation = { kind = "markdown", value = signature } }
  Lsp.resolve(Lsp.response(runtime.context("nor"), client, { raw }).items[1], function(result)
    t.assert_eq(raw, result, "other servers retain their documentation contract")
  end)
end)

t:test("LSP alternatives have distinct identities while acceptance history remains stable", function()
  local context = runtime.context("al")
  local client = { id = 10, name = "fixture", offset_encoding = "utf-16" }
  local raw =
    { label = "alpha", detail = "detail", labelDetails = { description = "description" }, insertText = "text" }
  local first = Lsp.response(context, client, { raw, raw }).items
  local second = Lsp.response(context, client, { raw }).items
  client.id = 11
  local restarted = Lsp.response(context, client, { raw }).items
  local seen = {}
  for _, item in ipairs({ first[1], first[2], restarted[1] }) do
    t.assert_false(seen[item.id], "each live client occurrence has an independent native identity")
    seen[item.id] = true
    t.assert_eq("lsp\0fixture\0alpha\0description\0detail\0text", item.frecency_key, "persistent history format")
  end
  t.assert_true(first[1] ~= second[1], "a fresh response cannot inherit the old selection identity")
  t.assert_eq(first[1].frecency_key, second[1].frecency_key, "history survives a fresh response")
end)

t:test("nullable LSP capabilities do not invent trigger or resolve support", function()
  local context = runtime.context("al!")
  local client = {
    id = 10,
    name = "fixture",
    offset_encoding = "utf-16",
    server_capabilities = {
      completionProvider = { triggerCharacters = vim.NIL, resolveProvider = vim.NIL },
      signatureHelpProvider = { triggerCharacters = vim.NIL, retriggerCharacters = vim.NIL },
    },
    request = function(_, method, params, callback)
      t.assert_eq("textDocument/completion", method, "null resolveProvider is not enabled")
      t.assert_eq(1, params.context.triggerKind, "no trigger character was advertised")
      callback(nil, { { label = "alpha" } })
      return true, 1
    end,
    cancel_request = function() end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)
  t.assert_eq(0, #require("era.keystroke.cmp.policy").sources_for(context, false), "punctuation is not a trigger")
  local response
  t:defer(Lsp.complete(context, function(value)
    response = value
  end))
  local resolved
  t.assert_nil(Lsp.resolve(response.items[1], function(value)
    resolved = value
  end))
  t.assert_eq(response.items[1].raw, resolved, "unsupported resolve returns the original payload")
  local signature = require("era.keystroke.cmp.signature").new()
  t:defer(function()
    signature:destroy()
  end)
  t.assert_false(signature:update(context), "null character arrays do not trigger signature help")
  client.server_capabilities.signatureHelpProvider = vim.NIL
  t.assert_false(signature:update(context), "null signature provider is ignored")
end)

t:run()
