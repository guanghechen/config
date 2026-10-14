local harness = require("__test__.support.harness")
local runtime = require("__test__.fixtures.era.keystroke.cmp.runtime")
runtime.setup()
local t = harness.new("era.keystroke.cmp.sources")
local Context = require("era.keystroke.cmp.context")
local Path = require("era.keystroke.cmp.source.path")
local Lsp = require("era.keystroke.cmp.source.lsp")

---@param lines                         string[]
---@return integer
local function buffer_fixture(lines)
  local previous = vim.api.nvim_get_current_buf()
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  t:defer(function()
    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = { { bufnr = bufnr } } }
  end)
  return bufnr
end

---@return string[]
local function completed_words()
  local words = {}
  require("era.keystroke.cmp.source.buffer").complete(runtime.context(""), function(response)
    for _, item in ipairs(response.items) do
      words[#words + 1] = item.raw.label
    end
  end)
  table.sort(words)
  return words
end

---@param lines                         string[]
---@return string[]
local function scanned_words(lines)
  local pattern = vim.regex([[\k\{3,}]])
  local words, seen = {}, {}
  for _, line in ipairs(lines) do
    local offset = 0
    while offset < #line do
      local left, right = pattern:match_str(line:sub(offset + 1))
      if left == nil then
        break
      end
      local word = line:sub(offset + left + 1, offset + right)
      if not seen[word] then
        words[#words + 1] = word
        seen[word] = true
      end
      offset = offset + right
    end
  end
  table.sort(words)
  return words
end

t:test("path parsing distinguishes workspace references and file-relative paths", function()
  t:patch_table(dot.path, "cwd", function()
    return "/workspace"
  end)
  local target = assert(Path.target(runtime.context("review @lua/era/cm")))
  t.assert_eq("/workspace/lua/era", target.dirname, "workspace directory")
  t.assert_eq(#"review @lua/era/", target.start_col, "basename start")
  t.assert_eq("path_at", target.source, "source label")
  target = assert(Path.target(runtime.context('"./folder with space/fi')))
  t.assert_true(target.dirname:match("folder with space$") ~= nil, "quoted space")
  t.assert_eq(nil, Path.target(runtime.context("object.member")), "ordinary identifier")
  for _, quote in ipairs({ '"', "'", "`" }) do
    t.assert_nil(Path.target(runtime.context("local text = " .. quote .. "word")), "plain quoted text")
  end
  local finder = runtime.context("folder")
  finder.filetype = stl.filetype.UX_PICKER_FINDER
  t.assert_eq("/workspace", assert(Path.target(finder)).dirname, "finder basenames remain paths")
end)

t:test("path targets reject invalid UTF-8 origins without invoking native path conversion", function()
  local bufnr = buffer_fixture({ "" })
  t.assert_eq(nil, Path.target(runtime.context('"/tmp/\255/a')), "typed directory")
  vim.api.nvim_buf_set_name(bufnr, "/tmp/\255/current.lua")
  t.assert_eq(nil, Path.target(runtime.context('"./a')), "buffer filename")
  vim.api.nvim_buf_set_name(bufnr, "")
  t:patch_table(dot.path, "cwd", function()
    return "/tmp/\255"
  end)
  t.assert_eq(nil, Path.target(runtime.context("@a")), "workspace directory")
  t:patch_table(dot.path, "cwd", function()
    return "/workspace"
  end)
  t:patch_table(vim.env, "CMP_UTF8_TARGET", "/tmp/\255")
  t.assert_eq(nil, Path.target(runtime.context('"$CMP_UTF8_TARGET/a')), "expanded environment directory")
  t.assert_eq("/workspace", assert(Path.target(runtime.context("@a"))).dirname, "valid targets remain usable")
end)

t:test("directory scans skip invalid UTF-8 file and symlink names while preserving valid entries", function()
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory .. "/child", "p")
  t:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  vim.fn.writefile({}, directory .. "/alpha.txt")
  vim.fn.writefile({}, directory .. "/a\255.txt")
  assert(vim.uv.fs_symlink(directory .. "/child", directory .. "/linked"))
  assert(vim.uv.fs_symlink(directory .. "/child", directory .. "/l\255"))
  local result
  t:defer(Path.complete(runtime.context('"' .. directory .. "/a"), function(response)
    result = response
  end))
  t.wait_until(function()
    return result ~= nil
  end, 3000, "directory scan completes despite invalid names")
  t.assert_eq(false, result.incomplete, "scan reaches the end and settles pending stats")
  local labels = {}
  for _, item in ipairs(result.items) do
    labels[#labels + 1] = item.raw.label
  end
  table.sort(labels)
  t.assert_eq("alpha.txt,child/,linked/", table.concat(labels, ","), "valid files and symlinks survive")
end)

t:test("directory scans include late entries and resolve symlink directories", function()
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  t:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  for index = 1, 225 do
    vim.fn.writefile({}, directory .. "/item" .. index)
  end
  vim.fn.mkdir(directory .. "/child")
  assert(vim.uv.fs_symlink(directory .. "/child", directory .. "/linked"))
  t:patch_table(dot.path, "cwd", function()
    return directory
  end)
  local result
  local cancel = Path.complete(runtime.context("@"), function(response)
    result = response
  end)
  t:defer(cancel)
  t.wait_until(function()
    return result ~= nil
  end, 3000, "asynchronous directory result")
  t.assert_eq(false, result.incomplete, "full directory")
  t.assert_eq(227, #result.items, "no truncation before filtering")
  local linked = false
  for _, item in ipairs(result.items) do
    linked = linked or item.raw.label == "linked/"
  end
  t.assert_true(linked, "directory symlink")
end)

t:test("cancelled path scans never publish and the same context can retry", function()
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  t:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  t:patch_table(dot.path, "cwd", function()
    return directory
  end)
  local calls = 0
  local context = runtime.context("@")
  local cancel = Path.complete(context, function()
    calls = calls + 1
  end)
  cancel()
  cancel()
  vim.wait(30)
  t.assert_eq(0, calls, "cancelled callback")
  local retry = Path.complete(context, function()
    calls = calls + 1
  end)
  t:defer(retry)
  t.wait_until(function()
    return calls == 1
  end, 1000, "retry")
end)

t:test("path documentation reads regular files and skips current FIFO targets", function()
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  t:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  vim.fn.writefile({ "preview body" }, directory .. "/regular.txt")
  vim.fn.writefile({}, directory .. "/changed")
  local created = vim.system({ "mkfifo", directory .. "/pipe" }):wait()
  t.assert_eq(0, created.code, created.stderr)
  assert(vim.uv.fs_symlink(directory .. "/pipe", directory .. "/pipe_link"))
  assert(vim.uv.fs_symlink(directory .. "/regular.txt", directory .. "/regular_link"))
  t:patch_table(dot.path, "cwd", function()
    return directory
  end)
  local result
  t:defer(Path.complete(runtime.context("@"), function(response)
    result = response
  end))
  t.wait_until(function()
    return result ~= nil
  end, 1000, "file and FIFO candidates")
  t.assert_eq(5, #result.items, "special files remain selectable")
  assert(vim.uv.fs_unlink(directory .. "/changed"))
  created = vim.system({ "mkfifo", directory .. "/changed" }):wait()
  t.assert_eq(0, created.code, created.stderr)
  local regular = { [directory .. "/regular.txt"] = true, [directory .. "/regular_link"] = true }
  local invalid_opens = 0
  local open = vim.uv.fs_open
  t:patch_table(vim.uv, "fs_open", function(path, flags, mode, callback)
    if not regular[path] then
      invalid_opens = invalid_opens + 1
      -- Keep a regression from hanging the test process in a real blocking FIFO open.
      callback("fixture rejects non-file read")
      return nil
    end
    return open(path, flags, mode, callback)
  end)
  for _, item in ipairs(result.items) do
    local resolved
    local cancel = Path.resolve(item, function(raw)
      resolved = raw
    end)
    if cancel ~= nil then
      t:defer(cancel)
    end
    t.wait_until(function()
      return resolved ~= nil
    end, 1000, item.raw.label .. " documentation")
    if regular[item.raw.data.full_path] then
      t.assert_true(resolved.documentation.value:find("preview body", 1, true) ~= nil, "regular file content")
    else
      t.assert_eq(item.raw, resolved, "non-file response is unchanged")
    end
  end
  t.assert_eq(0, invalid_opens, "no FIFO is opened, including replaced files and symlinks")
  local calls = 0
  local cancel = Path.resolve(result.items[1], function()
    calls = calls + 1
  end)
  assert(cancel)()
  vim.wait(20)
  t.assert_eq(0, calls, "cancellation before stat returns does not publish")
end)

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
  buffer_fixture({ "al" })
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
  t.assert_true(vim.deep_equal(original, raw), "source payload is immutable")
  local Rank = require("era.keystroke.cmp.rank")
  t.assert_eq(item, Rank.filter(context, Rank.prepare({ item }))[1], "candidate remains matchable")
end)

t:test("nullable completion edits inherit defaults and retain insert ranges", function()
  buffer_fixture({ "alTail" })
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
  buffer_fixture({ "al" })
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
  t.assert_true(vim.deep_equal(original, resolved), "resolve response is immutable")
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

t:test("ranking preserves LSP alternatives with distinct edits, commands or resolve payloads", function()
  local Rank = require("era.keystroke.cmp.rank")
  local context = runtime.context("FooTail", 3)
  local insertion = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } }
  for _, case in ipairs({
    {
      name = "imports",
      left = { additionalTextEdits = { { range = insertion, newText = "import a\n" } } },
      right = { additionalTextEdits = { { range = insertion, newText = "import b\n" } } },
    },
    { name = "resolve data", left = { data = { module = "a" } }, right = { data = { module = "b" } } },
    {
      name = "commands",
      left = { command = { title = "run", command = "fixture.a" } },
      right = { command = { title = "run", command = "fixture.b" } },
    },
    {
      name = "overload details",
      left = { labelDetails = { detail = "(): A" } },
      right = { labelDetails = { detail = "(): B" } },
    },
    { name = "kind-dependent brackets", left = { kind = 3 }, right = { kind = 6 } },
    {
      name = "snippet semantics",
      left = { insertText = "Foo($0)", insertTextFormat = 1 },
      right = { insertText = "Foo($0)", insertTextFormat = 2 },
    },
  }) do
    local response = Lsp.response(context, { id = 10, name = "fixture", offset_encoding = "utf-16" }, {
      vim.tbl_extend("force", { label = "Foo", insertText = "Foo", kind = 6 }, case.left),
      vim.tbl_extend("force", { label = "Foo", insertText = "Foo", kind = 6 }, case.right),
    })
    local ranked = Rank.filter(context, Rank.prepare(response.items))
    t.assert_eq(2, #ranked, case.name .. " alternatives remain selectable")
    t.assert_eq(response.items[1], ranked[1], case.name .. " keeps provider order")
    t.assert_eq(response.items[2], ranked[2], case.name .. " retains the second payload")
  end
end)

---@param count                         integer
---@return table
local function pending_lsp(count)
  buffer_fixture({ "" })
  local state = { clients = {}, requests = {}, cancellations = {} }
  for index = 1, count do
    local client = {
      id = 50300 + index,
      name = "fixture_" .. index,
      offset_encoding = "utf-8",
      server_capabilities = { completionProvider = {} },
    }
    client.request = function(_, method, params, callback)
      t.assert_eq("textDocument/completion", method)
      local id = #state.requests + 1
      state.requests[id] = { client = client, params = params, callback = callback }
      return true, id
    end
    client.cancel_request = function(_, id)
      state.cancellations[#state.cancellations + 1] = id
    end
    state.clients[index] = client
  end
  t:patch_table(vim.lsp, "get_clients", function()
    return state.clients
  end)
  ---@param query                       string
  ---@param callback                    fun(response: era.keystroke.cmp.IResponse): nil
  ---@param fields                      ?table
  ---@param dispatch                    ?era.keystroke.cmp.RequestDispatch
  ---@return fun(keep_transport?: boolean): nil
  function state:complete(query, callback, fields, dispatch)
    local cancel = Lsp.complete(vim.tbl_extend("force", runtime.context(query), fields or {}), callback, dispatch)
    t:defer(cancel)
    return cancel
  end
  return state
end

t:test("LSP coalesces compatible queries and publishes only to the latest owner", function()
  local state = pending_lsp(1)
  local obsolete, results = 0, {}
  local first = state:complete("a", function()
    obsolete = obsolete + 1
  end)
  local middle = state:complete("al", function()
    obsolete = obsolete + 1
  end)
  first()
  local latest = state:complete("alp", function(value)
    results[#results + 1] = value
  end)
  middle()
  t.assert_eq(1, #state.requests, "one transport while newer queries replace the subscriber")
  t.assert_eq(0, #state.cancellations, "superseded subscribers cannot cancel their successor")
  state.requests[1].callback(nil, { items = { { label = "alpha" } }, isIncomplete = true })
  t.assert_eq(0, obsolete, "obsolete consumers never publish")
  t.assert_eq("alpha", results[1].items[1].raw.label, "compatible partial results are immediately useful")
  t.assert_true(results[1].pending, "latest context still needs a server response")
  t.assert_eq(2, #state.requests, "only the latest queued query is submitted")
  t.assert_eq(3, state.requests[2].params.position.character)
  t.assert_eq(3, state.requests[2].params.context.triggerKind)
  state.requests[2].callback(nil, { items = { { label = "alpine" } }, isIncomplete = false })
  local response = results[#results]
  t.assert_eq("alpine", response.items[1].raw.label)
  t.assert_false(response.incomplete, "the latest response settles the queue")
  latest()
  t.assert_eq(0, #state.cancellations, "settled transports are not cancelled")
  state:complete("alpi", function(value)
    t.assert_eq(response.items, value.items, "complete cache keeps the same item array")
  end)
  t.assert_eq(2, #state.requests, "complete results do not need another request")
end)

t:test("coalesced LSP refresh uses the latest dispatch and discarded work remains retryable", function()
  local state = pending_lsp(1)
  local dispatched = {}
  local first = state:complete("a", function() end, nil, function(submit)
    dispatched[#dispatched + 1] = "first"
    submit()
  end)
  local latest = state:complete("al", function() end, nil, function(submit)
    dispatched[#dispatched + 1] = "latest"
    submit()
  end)
  first()
  state.requests[1].callback(nil, { items = { { label = "alpha" } }, isIncomplete = true })
  t.assert_eq("first,latest", table.concat(dispatched, ","), "dispatch follows the current subscriber")
  t.assert_eq(2, #state.requests)
  local discarded = state:complete("alp", function() end, nil, function()
    dispatched[#dispatched + 1] = "discarded"
  end)
  latest()
  state.requests[2].callback(nil, { items = { { label = "alpha" } }, isIncomplete = true })
  t.assert_eq("first,latest,discarded", table.concat(dispatched, ","))
  t.assert_eq(2, #state.requests, "discarded dispatch sends no transport")
  state:complete("alph", function() end, nil, function(submit)
    submit()
  end)
  discarded()
  t.assert_eq(3, #state.requests, "discarded work cannot strand the next query")
  t.assert_eq(4, state.requests[3].params.position.character)
  t.assert_eq(0, #state.cancellations, "old handles do not cancel the new owner")
end)

t:test("losing LSP ownership during dispatch prevents submission", function()
  local state = pending_lsp(1)
  local first = state:complete("a", function() end)
  local latest
  latest = state:complete("al", function() end, nil, function(submit)
    latest()
    submit()
  end)
  first()
  state.requests[1].callback(nil, { items = { { label = "alpha" } }, isIncomplete = true })
  t.assert_eq(1, #state.requests, "dispatch cannot send after cancellation")
  t.assert_eq(0, #state.cancellations, "a transport that never started cannot be cancelled")
  state:complete("alp", function() end)
  t.assert_eq(2, #state.requests, "later input starts a new request")
end)

t:test("input invalidation suspends queued LSP work while retaining the hard cancellation handle", function()
  local state = pending_lsp(1)
  local calls = 0
  local first = state:complete("a", function()
    calls = calls + 1
  end)
  local latest = state:complete("al", function()
    calls = calls + 1
  end)
  first()
  latest(true)
  t.assert_eq(0, #state.cancellations, "input invalidation retains the active transport")
  state.requests[1].callback(nil, { items = { { label = "alpha" } }, isIncomplete = true })
  t.assert_eq(0, calls, "invalidated consumers cannot publish between input and update")
  t.assert_eq(1, #state.requests, "an old queued position cannot run before the next context is captured")
  local current = state:complete("alp", function()
    calls = calls + 1
  end)
  t.assert_eq(2, #state.requests)
  t.assert_eq(3, state.requests[2].params.position.character, "only the observed latest position is requested")
  current(true)
  t.assert_eq(0, #state.cancellations)
  current()
  t.assert_eq(1, #state.cancellations, "Escape can still cancel the retained transport")
  state.requests[2].callback(nil, { { label = "ancient" } })
  t.assert_eq(0, calls, "the late cancelled reply stays suppressed")
end)

t:test("LSP backspace queries do not broaden a narrower completed response", function()
  local state = pending_lsp(1)
  local results = {}
  local first = state:complete("alph", function() end)
  state:complete("al", function(value)
    results[#results + 1] = value
  end)
  first()
  t.assert_eq(1, #state.requests, "backspace replaces the queued query")
  state.requests[1].callback(nil, { { label = "alpha" } })
  t.assert_eq(0, #results, "a narrower list is not presented as the widened query's result")
  t.assert_eq(2, #state.requests)
  t.assert_eq(2, state.requests[2].params.position.character)
  t.assert_eq(1, state.requests[2].params.context.triggerKind)
  state.requests[2].callback(nil, { { label = "alpine" }, { label = "alpha" } })
  t.assert_eq(2, #results[1].items, "the broader query keeps every returned candidate")
end)

t:test("LSP clients coalesce independently while fast results remain progressive", function()
  local state = pending_lsp(2)
  local before, after = {}, {}
  local first = state:complete("a", function(value)
    before[#before + 1] = value
  end)
  state.requests[1].callback(nil, { { label = "alpha" } })
  t.assert_eq("alpha", before[1].items[1].raw.label, "fast client does not wait for the slow client")
  t.assert_true(before[1].pending)
  state:complete("al", function(value)
    after[#after + 1] = value
  end)
  first()
  t.assert_eq(2, #state.requests, "complete fast cache and pending slow request are both reused")
  t.assert_eq(0, #state.cancellations)
  state.requests[2].callback(nil, { items = { { label = "albatross" } }, isIncomplete = true })
  t.assert_eq(2, #after[#after].items, "partial slow results join the fast candidates immediately")
  t.assert_true(after[#after].pending)
  t.assert_eq(3, #state.requests, "only the slow client refreshes")
  t.assert_eq(state.clients[2], state.requests[3].client)
  state.requests[3].callback(nil, { { label = "almond" } })
  t.assert_eq(false, after[#after].pending)
  t.assert_eq(false, after[#after].incomplete)
  t.assert_eq("alpha", after[#after].items[1].raw.label)
  t.assert_eq("almond", after[#after].items[2].raw.label)
end)

t:test("manual and incompatible LSP contexts cancel rather than inherit pending requests", function()
  local state = pending_lsp(1)
  for index, fields in ipairs({
    { trigger = "manual" },
    { buffer_version = -1 },
    { filetype = "python" },
    { row = 1 },
    { winnr = vim.api.nvim_get_current_win() + 100 },
    { line = "al suffix" },
  }) do
    local offset, cancelled = #state.requests, #state.cancellations
    local result
    local first = state:complete("a", function() end, { buffer_version = index })
    local latest = state:complete("al", function(value)
      result = value
    end, vim.tbl_extend("force", { buffer_version = index }, fields))
    first()
    t.assert_eq(offset + 2, #state.requests, "incompatible context requests fresh data")
    t.assert_eq(cancelled + 1, #state.cancellations, "old transport is cancelled once")
    state.requests[offset + 1].callback(nil, { { label = "ancient" } })
    t.assert_eq(nil, result, "cancelled replies cannot publish")
    state.requests[offset + 2].callback(nil, { { label = "alpine" } })
    t.assert_eq("alpine", result.items[1].raw.label)
    latest()
    t.assert_eq(cancelled + 1, #state.cancellations, "completed request has no remaining transport")
  end
  local offset = #state.requests
  state:complete("a", function() end)
  state.clients = {}
  state:complete("al", function(value)
    t.assert_eq(0, #value.items, "detached clients contribute no results")
    t.assert_eq(false, value.pending)
  end)
  t.assert_eq(offset + 1, state.cancellations[#state.cancellations], "detaching cancels the remaining transport")
  state.requests[offset + 1].callback(nil, { { label = "ancient" } })
end)

t:test("queued LSP refresh handles synchronous replies and failed submissions", function()
  local state = pending_lsp(1)
  local request = state.clients[1].request
  state.clients[1].request = function(client, method, params, callback)
    local ok, id = request(client, method, params, callback)
    if id == 3 then
      return false
    elseif id > 1 then
      callback(nil, { { label = "alpine" } })
    end
    return ok, id
  end
  local first = state:complete("a", function() end)
  local result
  state:complete("al", function(value)
    result = value
  end)
  first()
  state.requests[1].callback(nil, { items = { { label = "alpha" } }, isIncomplete = true })
  t.assert_eq(2, #state.requests)
  t.assert_eq("alpine", result.items[1].raw.label, "synchronous successor remains the newest result")
  state:complete("al", function(value)
    result = value
  end, { trigger = "manual" })
  t.assert_eq(0, #result.items, "submission failure settles without a timer wait")
  t.assert_true(result.incomplete, "failed submission remains retryable")
  state:complete("alp", function(value)
    result = value
  end)
  t.assert_eq(4, #state.requests)
  t.assert_eq("alpine", result.items[1].raw.label)
  t.assert_eq(0, #state.cancellations)
end)

t:test("a timed out LSP request releases fallback and cannot block its latest queued query", function()
  local state = pending_lsp(1)
  local first = state:complete("a", function() end)
  local result
  state:complete("al", function(value)
    result = value
  end)
  first()
  t.assert_eq(1, #state.requests, "latest query is initially queued")
  t.wait_until(function()
    return #state.requests == 2
  end, 3000, "stuck transport yields to the latest query")
  t.assert_eq(false, result.pending, "timeout permits buffer fallback during recovery")
  t.assert_true(result.incomplete)
  t.assert_eq(1, #state.cancellations, "only the stuck transport is cancelled")
  state.requests[1].callback(nil, { { label = "ancient" } })
  t.assert_eq(0, #result.items, "late cancelled response is ignored")
  state.requests[2].callback(nil, { { label = "alpine" } })
  t.assert_eq("alpine", result.items[1].raw.label, "latest response replaces temporary fallback")
  state:complete("alp", function(value)
    t.assert_eq("alpine", value.items[1].raw.label, "cancelled response cannot poison the cache")
  end)
  t.assert_eq(2, #state.requests)
end)

t:test("LSP fallback readiness is independent of isIncomplete and waits for every client", function()
  local callbacks, clients, responses = {}, {}, {}
  for index = 1, 2 do
    clients[index] = {
      id = 50100 + index,
      offset_encoding = "utf-8",
      server_capabilities = { completionProvider = {} },
      request = function(_, _, _, callback)
        callbacks[index] = callback
        return true, index
      end,
      cancel_request = function() end,
    }
  end
  t:patch_table(vim.lsp, "get_clients", function()
    return clients
  end)
  t:defer(Lsp.complete(runtime.context("al"), function(response)
    responses[#responses + 1] = response
  end))
  callbacks[1](nil, { items = {}, isIncomplete = true })
  t.assert_true(responses[#responses].pending, "remaining client prevents premature fallback")
  callbacks[2](nil, { items = {}, isIncomplete = false })
  t.assert_eq(false, responses[#responses].pending, "all responses have settled")
  t.assert_true(responses[#responses].incomplete, "server isIncomplete is preserved for future requests")
end)

t:test("LSP timeout releases fallback while retaining ownership of a later response", function()
  local callback, result
  local client = {
    id = 50200,
    offset_encoding = "utf-8",
    server_capabilities = { completionProvider = {} },
    request = function(_, _, _, fn)
      callback = fn
      return true, 1
    end,
    cancel_request = function() end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)
  t:defer(Lsp.complete(runtime.context("al"), function(response)
    result = response
  end))
  t.assert_eq(nil, result, "pending source does not publish an immediate empty result")
  t.wait_until(function()
    return result ~= nil
  end, 3000, "source timeout publishes fallback eligibility")
  t.assert_eq(false, result.pending, "timeout releases the fallback dependency")
  t.assert_true(result.incomplete, "pending server response remains retryable")
  callback(nil, { items = { { label = "alpha" } }, isIncomplete = false })
  t.assert_eq("alpha", result.items[1].raw.label, "late response for the active request is still useful")
end)

t:test("different directory prefixes and buffer revisions invalidate caches", function()
  t.assert_true(Context.extends(runtime.context("@lua/era/"), runtime.context("@lua/era/p")), "basename continuation")
  t.assert_eq(false, Context.extends(runtime.context("@lua/era/p"), runtime.context("@lua/e")), "directory changed")
  local current = runtime.context("foobar")
  current.buffer_version = 1
  t.assert_eq(false, Context.extends(runtime.context("foo"), current), "external buffer edit")
end)

t:test("slash commands continue across hyphens and carry their own edit range", function()
  local response
  require("era.keystroke.cmp.source.slash").complete(runtime.context("请 /code-an"), function(value)
    response = value
  end)
  t.assert_true(#response.items > 0, "slash commands")
  t.assert_eq(#"请 ", response.items[1].start_col, "byte edit start")
  t.assert_eq("/code-analyze ", response.items[1].raw.textEdit.newText, "insert command")
end)

t:test("buffer limits count eligible buffers and retain the current buffer in tab order", function()
  local entries = {}
  local nofile_bufnr = buffer_fixture({ "ignored_nofile" })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = nofile_bufnr })
  entries[#entries + 1] = { bufnr = nofile_bufnr }
  entries[#entries + 1] = { bufnr = buffer_fixture({ "ignored_large" .. string.rep(" ", 131072) }) }
  for index = 1, 9 do
    entries[#entries + 1] = { bufnr = buffer_fixture({ "candidate_" .. index }) }
  end
  local bufnr = buffer_fixture({ "current_candidate" })
  entries[#entries + 1] = { bufnr = bufnr }
  entries[#entries + 1] = { bufnr = buffer_fixture({ "beyond_limit" }) }
  vim.api.nvim_set_current_buf(bufnr)
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = entries }
  end)
  local words = completed_words()
  t.assert_eq(10, #words, "ten eligible buffers")
  t.assert_true(vim.list_contains(words, "current_candidate"), "current buffer is the tenth eligible entry")
  for _, word in ipairs({ "ignored_nofile", "ignored_large", "beyond_limit" }) do
    t.assert_eq(false, vim.list_contains(words, word), word .. " is excluded")
  end
end)

t:test("buffer size budget skips oversized entries and admits later small buffers", function()
  local entries = {}
  for _, entry in ipairs({
    { label = "first", size = 120000 },
    { label = "second", size = 120000 },
    { label = "third", size = 120000 },
    { label = "fourth", size = 120000 },
    { label = "over_budget", size = 25000 },
    { label = "tail", size = 100 },
  }) do
    local bufnr = buffer_fixture({ entry.label .. string.rep(" ", entry.size - #entry.label - 1) })
    entries[#entries + 1] = { bufnr = bufnr }
  end
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = entries }
  end)
  t.assert_eq("first,fourth,second,tail,third", table.concat(completed_words(), ","), "500000 byte budget")
end)

t:test("buffer tokenization preserves Unicode and deduplicates words", function()
  buffer_fixture({ "alpha beta alpha", "中文变量 value_123" })
  local words = completed_words()
  t.assert_true(vim.list_contains(words, "中文变量"), "Unicode word")
  t.assert_eq(4, #words, "unique words")
end)

t:test("buffer words exclude malformed UTF-8 without discarding valid words on the same line", function()
  local bufnr = buffer_fixture({ "\255broken alpha 中文变量" })
  t.assert_eq("alpha,中文变量", table.concat(completed_words(), ","), "invalid token excluded")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "repaired alpha 中文变量" })
  t.assert_eq("alpha,repaired,中文变量", table.concat(completed_words(), ","), "repaired tokens rejoin the cache")
end)

t:test("ASCII tokenization agrees with Vim keyword matching and falls back for custom options", function()
  local lines = { "foo-bar value_123 a ab abc 123 $foo", "abc 中文变量 éclair", "before\0after" }
  local bufnr = buffer_fixture(lines)
  for _, keyword in ipairs({ "@,48-57,_,192-255", "@,48-57,_,192-255,-", "@,_" }) do
    vim.api.nvim_set_option_value("iskeyword", keyword, { buf = bufnr })
    local expected = scanned_words(lines)
    local actual = completed_words()
    t.assert_eq(table.concat(expected, "\n"), table.concat(actual, "\n"), keyword .. " token boundaries")
  end
end)

t:test("buffer cache applies batched line insertions and deletions without losing duplicate words", function()
  local bufnr = buffer_fixture({ "" })
  ---@return string
  local function labels()
    return table.concat(completed_words(), ",")
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "alpha shared", "beta shared", "gamma" })
  t.assert_eq("alpha,beta,gamma,shared", labels(), "initial words")
  vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "delta shared", "added_word" })
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, {})
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "tail_word shared" })
  t.assert_eq("added_word,delta,gamma,shared,tail_word", labels(), "batched splices")
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, {})
  t.assert_eq("added_word,gamma,shared,tail_word", labels(), "one shared occurrence remains")
  vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, {})
  t.assert_eq("added_word,gamma", labels(), "last shared occurrence removed")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "foo-bar baz", "" })
  t.assert_eq("bar,baz,foo", labels(), "default keyword option")
  vim.api.nvim_set_option_value("iskeyword", "@,48-57,_,192-255,-", { buf = bufnr })
  t.assert_eq("baz,foo-bar", labels(), "option changes invalidate cached tokens")
  for index = 1, 150 do
    vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "latest_" .. index })
  end
  t.assert_eq("baz,foo-bar,latest_150", labels(), "bounded edit log rebuilds from final text")
  for step = 1, 150 do
    local size = vim.api.nvim_buf_line_count(bufnr)
    local first = (step * 17) % (size + 1)
    local last = math.min(size, first + step % 3)
    local replacement = step % 4 == 0 and {} or { "word_" .. step .. " shared", "shared foo-bar" }
    vim.api.nvim_buf_set_lines(bufnr, first, last, false, replacement)
    if step % 5 == 0 then
      local expected = scanned_words(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
      t.assert_eq(table.concat(expected, ","), labels(), "full-rescan oracle after edit " .. step)
    end
  end
end)

t:test("sparse buffer caches survive empty-row edits, undo and redo", function()
  local bufnr = buffer_fixture({ "", "alpha", "", "", "shared", "" })
  t.assert_eq("alpha,shared", table.concat(completed_words(), ","))
  t.assert_eq("alpha,shared", table.concat(completed_words(), ","), "unchanged cache")
  vim.cmd("let &l:undolevels = &l:undolevels")
  vim.api.nvim_buf_set_lines(bufnr, 2, 4, false, { "beta shared", "", "" })
  t.assert_eq("alpha,beta,shared", table.concat(completed_words(), ","), "formerly empty rows gain words")
  vim.cmd.undo()
  t.assert_eq("alpha,shared", table.concat(completed_words(), ","), "undo restores empty rows")
  vim.cmd.redo()
  t.assert_eq("alpha,beta,shared", table.concat(completed_words(), ","), "redo restores word counts")
  vim.api.nvim_buf_set_lines(bufnr, 1, 3, false, { "", "" })
  t.assert_eq("shared", table.concat(completed_words(), ","), "another row still owns the shared word")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "", "", "" })
  t.assert_eq(0, #completed_words(), "all empty rows release old words")
  t.assert_eq(0, #completed_words(), "empty cache remains reusable")
  vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "new_word" })
  t.assert_eq("new_word", table.concat(completed_words(), ","), "editing one empty row keeps the others empty")
end)

t:test("buffer reload and detach discard even an unchanged sparse cache", function()
  local path = vim.fn.tempname() .. ".txt"
  vim.fn.writefile({ "", "alpha", "" }, path)
  t:defer(function()
    vim.fn.delete(path)
  end)
  local bufnr = buffer_fixture({ "", "alpha", "" })
  vim.api.nvim_buf_set_name(bufnr, path)
  t.assert_eq("alpha", table.concat(completed_words(), ","))
  t.assert_eq("alpha", table.concat(completed_words(), ","), "warm sparse cache")
  vim.fn.writefile({ "", "beta", "", "" }, path)
  vim.cmd.edit({ bang = true })
  t.assert_eq("beta", table.concat(completed_words(), ","), "same buffer reloads disk words")
  t.assert_eq("beta", table.concat(completed_words(), ","))
  vim.api.nvim_buf_delete(bufnr, { unload = true })
  vim.fn.writefile({ "", "gamma", "" }, path)
  vim.fn.bufload(bufnr)
  vim.api.nvim_set_current_buf(bufnr)
  t.assert_eq("gamma", table.concat(completed_words(), ","), "detached buffer rebuilds when loaded again")
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "delta" })
  t.assert_eq("delta,gamma", table.concat(completed_words(), ","), "reloaded buffer keeps its new listener")
end)

t:test("snippet variables preserve escaped literals and nested placeholders", function()
  local context = runtime.context("fn")
  local filename = vim.fn.tempname() .. "/sample.lua"
  local old_name = vim.api.nvim_buf_get_name(0)
  vim.api.nvim_buf_set_name(0, filename)
  t:defer(function()
    vim.api.nvim_buf_set_name(0, old_name)
  end)
  local expanded = require("era.keystroke.cmp.snippet").expand_variables(
    "${1:${TM_FILENAME_BASE}} \\$TM_FILENAME_BASE $TM_FILENAME",
    context
  )
  t.assert_eq("${1:sample} \\$TM_FILENAME_BASE sample.lua", expanded, "escaped variable remains literal")
end)

t:run()
