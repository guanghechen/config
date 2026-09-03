---@diagnostic disable: undefined-global

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.cmp.bridge")

_G.yoz = require("yoz")
bootstrap.with_stl(t, {
  reporter = {
    warn = function() end,
  },
})

local local_result = { isIncomplete = true, items = {} } ---@type lsp.CompletionList
local defer_local = false ---@type boolean
t:patch_table(package.loaded, "era.m.cmp.source", {
  complete = function(_, _, callback)
    if not defer_local then
      callback(vim.deepcopy(local_result))
    end
    return function() end, function()
      return vim.deepcopy(local_result)
    end
  end,
})

local Bridge = require("era.m.cmp.bridge")
vim.o.virtualedit = "onemore"
t:patch_table(vim.api, "nvim_get_mode", function()
  return { mode = "i" }
end)
local refreshes = {} ---@type integer[]
Bridge.set_refresh(function(bufnr)
  refreshes[#refreshes + 1] = bufnr
  return true
end)

---@param line                          string
---@return integer, lsp.CompletionParams
local function context(line)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".lua")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { line })
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_win_set_cursor(0, { 1, #line })
  return bufnr,
    {
      textDocument = { uri = vim.uri_from_bufnr(bufnr) },
      position = { line = 0, character = #line },
    }
end

t:test("completion outside insert mode settles without starting providers", function()
  local bufnr, params = context("value")
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "n" }
  end)
  t:patch_table(vim.lsp, "get_clients", function()
    error("providers must not start outside insert mode", 0)
  end)

  local result
  Bridge.complete(params, function(err, value)
    t.assert_nil(err, "completion error")
    result = value
  end)

  t.assert_false(result.isIncomplete, "terminal result")
  t.assert_eq(0, #result.items, "empty result")
  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("normalizes local and LSP items to one replacement boundary", function()
  local line = "require('plenary.asy"
  local bufnr, params = context(line)
  local_result.items = {
    {
      label = "async",
      kind = vim.lsp.protocol.CompletionItemKind.Text,
      textEdit = {
        newText = "async",
        range = { start = { line = 0, character = 17 }, ["end"] = params.position },
      },
      data = { era_cmp = { source = "path", priority = 200, score = 200, exact = false } },
    },
  }

  local client = {
    id = 42,
    name = "lua_ls",
    offset_encoding = "utf-8",
    request = function(_, method, _, callback)
      t.assert_eq("textDocument/completion", method, "request method")
      callback(nil, {
        isIncomplete = false,
        items = {
          {
            label = "async",
            kind = vim.lsp.protocol.CompletionItemKind.Function,
            filterText = "plenary.async",
            textEdit = {
              newText = "plenary.async",
              range = { start = { line = 0, character = 9 }, ["end"] = params.position },
            },
          },
        },
      })
      return true, 7
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local result
  Bridge.complete(params, function(err, value)
    t.assert_nil(err, "completion error")
    result = value
  end)

  t.assert_eq(2, #result.items, "merged items")
  for _, item in ipairs(result.items) do
    t.assert_eq(9, item.textEdit.range.start.character, "shared boundary")
    t.assert_eq("plenary.async", item.textEdit.newText, "normalized text")
    local meta = item._era_cmp_meta or item.data.era_cmp
    t.assert_eq("string", type(meta.source), "shared ranking projection stays internal")
  end
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("preserves replacement suffix metadata and normalizes snippet text", function()
  local line = "foobar"
  local bufnr, params = context(line)
  params.position.character = 3
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  local_result.items = {}
  local client = {
    id = 46,
    name = "suffix-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      callback(nil, {
        items = {
          {
            label = "fooBar",
            insertText = "fooBar(${1:value})",
            insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
            textEdit = {
              newText = "fooBar(${1:value})",
              range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
            },
          },
        },
      })
      return true, 11
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local result
  Bridge.complete(params, function(_, value)
    result = value
  end)
  local item = assert(result.items[1])
  t.assert_eq(3, item._era_cmp_suffix_bytes, "suffix bytes")
  t.assert_nil(item.insertText, "normalized insertText")
  t.assert_eq("fooBar(${1:value})", item.textEdit.newText, "normalized snippet")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("applies persisted frecency in the shared Rust ranking", function()
  local bufnr, params = context("alpha")
  local dict_key = require("era.m.cmp.source.util").usage_key("dict", { label = "alpha" })
  local_result.items = {
    {
      label = "alpha",
      data = { era_cmp = { source = "buffer", priority = 100, score = 100, exact = false } },
    },
    {
      label = "alpha",
      data = { era_cmp = { source = "dict", priority = 100, score = 100, exact = false } },
    },
  }
  Bridge.set_history({
    [dict_key] = { count = 4, last_used = os.time() - 60 },
  })
  t:patch_table(vim.lsp, "get_clients", function()
    return {}
  end)

  local result
  Bridge.complete(params, function(_, value)
    result = value
  end)
  t.assert_eq("dict", result.items[1].data.era_cmp.source, "recent source")

  Bridge.set_history({})
  Bridge.record_history(dict_key, os.time())
  local snapshot = Bridge.snapshot_history(os.time())
  t.assert_true(snapshot[dict_key].score > 0, "persisted decayed score")
  Bridge.complete(params, function(_, value)
    result = value
  end)
  t.assert_eq("dict", result.items[1].data.era_cmp.source, "incremental history update")

  Bridge.set_history({})
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("nearby words improve otherwise tied completion ordering", function()
  local bufnr, params = context("alpha")
  local lines = { "alphaOne" }
  for index = 2, 40 do
    lines[index] = "filler" .. index
  end
  lines[41] = "alphaTwo"
  lines[42] = "alpha"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 42, 5 })
  params.position = { line = 41, character = 5 }
  local_result.items = {
    {
      label = "alphaOne",
      sortText = "a",
      data = { era_cmp = { source = "buffer", priority = 100, score = 100, exact = false } },
    },
    {
      label = "alphaTwo",
      sortText = "z",
      data = { era_cmp = { source = "buffer", priority = 100, score = 100, exact = false } },
    },
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return {}
  end)

  local result
  Bridge.complete(params, function(_, value)
    result = value
  end)

  t.assert_eq("alphaTwo", result.items[1].label, "nearby candidate")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("caps the ranked list at the Blink default", function()
  local bufnr, params = context("item")
  local_result.items = {}
  for index = 1, 250 do
    local label = string.format("item%03d", index)
    local_result.items[index] = {
      label = label,
      filterText = label,
      sortText = string.format("%03d", 251 - index),
      data = { era_cmp = { source = "buffer", priority = 100, score = 100, exact = false } },
    }
  end
  t:patch_table(vim.lsp, "get_clients", function()
    return {}
  end)

  local result
  Bridge.complete(params, function(_, value)
    result = value
  end)
  t.assert_eq(200, #result.items, "global item limit")
  t.assert_eq("item250", result.items[1].label, "first sort text")
  t.assert_eq("item051", result.items[200].label, "last retained sort text")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("global LSP ranking and cached refresh stay within the popup latency budget at scale", function()
  local bufnr, params = context("item")
  local_result.items = {}
  local items = {} ---@type lsp.CompletionItem[]
  local requests = 0
  local defer_refresh = false
  local refresh_callback = nil ---@type function|nil
  for index = 1, 5000 do
    local label = string.format("item%05d", index)
    items[index] = {
      label = label,
      kind = vim.lsp.protocol.CompletionItemKind.Function,
      detail = "function " .. label,
      textEdit = {
        newText = label,
        range = { start = { line = 0, character = 0 }, ["end"] = params.position },
      },
    }
  end
  local client = {
    id = 73,
    name = "scale-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      requests = requests + 1
      if defer_refresh then
        refresh_callback = callback
        return true, 73
      end
      callback(nil, { isIncomplete = true, items = items })
      return true, 73
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local result
  local started = vim.uv.hrtime()
  Bridge.complete(params, function(_, value)
    result = value
  end)
  local elapsed_ms = (vim.uv.hrtime() - started) / 1000000

  print(string.format("BENCH cmp bridge lsp5k=%.3fms", elapsed_ms))
  t.assert_eq(200, #result.items, "global result limit")
  t.assert_true(elapsed_ms < 100, string.format("global LSP ranking %.3fms", elapsed_ms))

  params.context = {
    triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerForIncompleteCompletions,
  }
  defer_refresh = true
  started = vim.uv.hrtime()
  Bridge.complete(params, function(_, value)
    result = value
  end)
  local cached_refresh_ms = (vim.uv.hrtime() - started) / 1000000

  print(string.format("BENCH cmp bridge lsp5k-cached=%.3fms", cached_refresh_ms))
  t.assert_eq(2, requests, "incomplete refresh count")
  t.assert_eq(200, #result.items, "refresh result limit")
  t.assert_true(cached_refresh_ms < 10, string.format("cached LSP refresh %.3fms", cached_refresh_ms))

  started = vim.uv.hrtime()
  assert(refresh_callback)(nil, { isIncomplete = true, items = items })
  local response_ms = (vim.uv.hrtime() - started) / 1000000
  print(string.format("BENCH cmp bridge lsp5k-response=%.3fms", response_ms))
  t.assert_true(response_ms < 100, string.format("LSP response merge %.3fms", response_ms))
  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("translates UTF-8 positions and forwards resolve and commands", function()
  local line = "你as"
  local bufnr, params = context(line)
  vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, { "你" })
  local_result.items = {}
  local forwarded_character
  local executed
  local client = {
    id = 43,
    name = "unicode-lsp",
    offset_encoding = "utf-16",
    supports_method = function(_, method)
      return method == "completionItem/resolve"
    end,
    request = function(_, method, request, callback)
      if method == "textDocument/completion" then
        forwarded_character = request.position.character
        callback(nil, {
          items = {
            {
              label = "async",
              textEdit = {
                newText = "async",
                range = { start = { line = 0, character = 1 }, ["end"] = { line = 0, character = 3 } },
              },
              command = { command = "apply", arguments = { 1 } },
            },
          },
        })
      else
        callback(nil, {
          label = request.label,
          additionalTextEdits = {
            {
              newText = "x",
              range = { start = { line = 1, character = 1 }, ["end"] = { line = 1, character = 1 } },
            },
          },
          command = request.command,
        })
      end
      return true, 8
    end,
    exec_cmd = function(_, command, opts)
      executed = { command = command, opts = opts }
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)

  local completion
  Bridge.complete(params, function(_, value)
    completion = assert(value).items[1]
  end)
  t.assert_eq(3, forwarded_character, "UTF-16 request column")
  t.assert_nil(completion._era_cmp_meta.usage_key, "usage identity starts lazy")

  local resolved
  Bridge.resolve(completion, function(err, value)
    t.assert_nil(err, "resolve error")
    resolved = value
  end)
  t.assert_eq(3, resolved.additionalTextEdits[1].range.start.character, "UTF-8 edit column")
  t.assert_eq(Bridge.get_usage_key(completion), Bridge.get_usage_key(resolved), "resolve-stable usage identity")

  Bridge.execute_command(resolved.command, { bufnr = bufnr })
  t.assert_eq("apply", executed.command.command, "upstream command")
  t.assert_eq(bufnr, executed.opts.bufnr, "command buffer")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("resolved usage identity boosts the next unresolved candidate", function()
  local bufnr, params = context("pri")
  local_result.items = {}
  local client = {
    id = 75,
    name = "resolve-identity-lsp",
    offset_encoding = "utf-8",
    supports_method = function(_, method)
      return method == "completionItem/resolve"
    end,
    request = function(_, method, request, callback)
      if method == "textDocument/completion" then
        callback(nil, {
          items = {
            { label = "print", detail = "competitor", sortText = "1" },
            { label = "print", detail = "target", sortText = "2" },
          },
        })
      else
        callback(
          nil,
          vim.tbl_extend("force", vim.deepcopy(request), {
            detail = "resolved target",
            command = { title = "run", command = "resolve.target", arguments = { "resolved" } },
          })
        )
      end
      return true, 75
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)

  local initial
  Bridge.complete(params, function(_, value)
    initial = value
  end)
  t.assert_eq("competitor", initial.items[1].detail, "initial sortText order")
  local resolved
  Bridge.resolve(initial.items[2], function(_, value)
    resolved = value
  end)
  local key = Bridge.get_usage_key(resolved)
  Bridge.set_history({ [key] = { count = 12, last_used = os.time() } })

  local ranked
  Bridge.complete(params, function(_, value)
    ranked = value
  end)
  t.assert_eq("target", ranked.items[1].detail, "unresolved candidate receives frecency")
  Bridge.set_history({})
  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("resolve converts same-line UTF-16 edits against the original completion text", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "long你Z" })
  local client = {
    id = 64,
    name = "unicode-resolve",
    offset_encoding = "utf-16",
    supports_method = function()
      return true
    end,
    request = function(_, _, _, callback)
      callback(nil, {
        additionalTextEdits = {
          {
            newText = "Y",
            range = { start = { line = 0, character = 2 }, ["end"] = { line = 0, character = 3 } },
          },
        },
      })
      return true, 64
    end,
  }
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)
  local item = {
    label = "long",
    textEdit = {
      newText = "long",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 1 } },
    },
    _era_cmp_meta = { source = "unicode-resolve" },
    _era_cmp_origin = {
      client_id = client.id,
      context = {
        bufnr = bufnr,
        row = 0,
        col = 1,
        line = "a你Z",
        filetype = "lua",
        start_col = 0,
        end_col = 1,
        keyword = "a",
      },
      item = {
        label = "long",
        textEdit = {
          newText = "long",
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 1 } },
        },
      },
      start_col = 0,
      target_start_col = 0,
      suffix_bytes = 0,
    },
  }

  local resolved
  Bridge.resolve(item, function(err, value)
    t.assert_nil(err, "resolve error")
    resolved = value
  end)

  t.assert_eq(4, resolved.additionalTextEdits[1].range.start.character, "original UTF-8 start")
  t.assert_eq(5, resolved.additionalTextEdits[1].range["end"].character, "original UTF-8 end")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("resolve converts later-line edits against an immutable text snapshot", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "foo", "bar", "你x" })
  local client = {
    id = 65,
    name = "multiline-unicode-resolve",
    offset_encoding = "utf-16",
    supports_method = function()
      return true
    end,
    request = function(_, _, _, callback)
      callback(nil, {
        additionalTextEdits = {
          {
            newText = "Y",
            range = { start = { line = 1, character = 1 }, ["end"] = { line = 1, character = 2 } },
          },
        },
      })
      return true, 65
    end,
  }
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)
  local item = {
    label = "foo bar",
    textEdit = {
      newText = "foo\nbar",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 1 } },
    },
    _era_cmp_meta = { source = client.name },
    _era_cmp_origin = {
      client_id = client.id,
      context = {
        bufnr = bufnr,
        row = 0,
        col = 1,
        line = "f",
        filetype = "lua",
        start_col = 0,
        end_col = 1,
        keyword = "f",
      },
      item = {
        label = "foo bar",
        textEdit = {
          newText = "foo\nbar",
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 1 } },
        },
      },
      start_col = 0,
      target_start_col = 0,
      suffix_bytes = 0,
    },
  }

  local resolved
  Bridge.resolve(item, function(err, value)
    t.assert_nil(err, "resolve error")
    resolved = value
  end, { "f", "你x" })

  t.assert_eq(3, resolved.additionalTextEdits[1].range.start.character, "snapshot UTF-8 start")
  t.assert_eq(4, resolved.additionalTextEdits[1].range["end"].character, "snapshot UTF-8 end")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("forwards trigger characters only to clients that declare them", function()
  local bufnr, params = context("vim.")
  params.context = {
    triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter,
    triggerCharacter = ".",
  }
  local contexts = {} ---@type table<string, lsp.CompletionContext>
  local clients = {
    {
      id = 61,
      name = "supports-dot",
      offset_encoding = "utf-8",
      server_capabilities = { completionProvider = { triggerCharacters = { "." } } },
    },
    {
      id = 62,
      name = "does-not-support-dot",
      offset_encoding = "utf-8",
      server_capabilities = { completionProvider = { triggerCharacters = { ":" } } },
    },
  }
  for _, client in ipairs(clients) do
    client.request = function(_, _, request, callback)
      contexts[client.name] = request.context
      callback(nil, { items = {} })
      return true, client.id
    end
  end
  t:patch_table(vim.lsp, "get_clients", function()
    return clients
  end)

  Bridge.complete(params, function() end)

  t.assert_eq(
    vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter,
    contexts["supports-dot"].triggerKind,
    "declared trigger"
  )
  t.assert_eq(".", contexts["supports-dot"].triggerCharacter, "trigger character")
  t.assert_eq(
    vim.lsp.protocol.CompletionTriggerKind.Invoked,
    contexts["does-not-support-dot"].triggerKind,
    "undeclared trigger"
  )
  t.assert_nil(contexts["does-not-support-dot"].triggerCharacter, "removed trigger character")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("drops a completion response after the trigger context changes", function()
  local bufnr, params = context("alpha")
  local_result.items = {}
  local respond = nil ---@type function|nil
  local client = {
    id = 63,
    name = "delayed-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      respond = callback
      return true, 63
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  refreshes = {}
  local result
  Bridge.complete(params, function(_, value)
    result = value
  end)
  vim.api.nvim_set_current_line("alpha;")
  vim.api.nvim_win_set_cursor(0, { 1, 6 })
  assert(respond)(nil, { items = { { label = "alphabet" } } })
  vim.wait(50)

  t.assert_eq(0, #result.items, "stale items")
  t.assert_false(result.isIncomplete, "stale terminal result")
  t.assert_eq(0, #refreshes, "stale refresh")
  Bridge.cancel(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("merges prompt upstream results into the initial snapshot and refreshes later results", function()
  local bufnr, params = context("va")
  local_result.items = {
    {
      label = "value",
      data = { era_cmp = { source = "buffer", priority = 100, score = 100, exact = false } },
    },
  }
  refreshes = {}
  local responses = {} ---@type table<integer, function>
  local clients = {
    { id = 65, name = "first-lsp", offset_encoding = "utf-8" },
    { id = 66, name = "second-lsp", offset_encoding = "utf-8" },
  }
  for _, client in ipairs(clients) do
    client.request = function(_, _, _, callback)
      responses[client.id] = callback
      return true, client.id
    end
  end
  t:patch_table(vim.lsp, "get_clients", function()
    return clients
  end)

  local initial
  Bridge.complete(params, function(_, value)
    initial = value
  end)
  t.assert_nil(initial, "initial grace period")

  responses[65](nil, { items = { { label = "variant" } } })
  t.wait_until(function()
    return initial ~= nil
  end, 1000, "initial merged result")
  t.assert_eq(2, #initial.items, "prompt upstream merge")
  t.assert_eq(0, #refreshes, "no redundant initial refresh")

  responses[66](nil, { items = { { label = "variable" } } })
  t.wait_until(function()
    return #refreshes == 1
  end, 1000, "late refresh")
  local final
  Bridge.complete(params, function(_, value)
    final = value
  end)
  t.assert_eq(3, #final.items, "final upstream merge")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("retains matching upstream candidates while a token grows", function()
  local bufnr, params = context("lZZ")
  vim.api.nvim_win_set_cursor(0, { 1, 1 })
  params.position.character = 1
  local_result.items = {}
  local query = "l"
  local requests = 0
  local client = {
    id = 67,
    name = "cached-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      requests = requests + 1
      local items = query == "l"
          and {
            {
              label = "local function",
              textEdit = {
                newText = "local function",
                range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
              },
              additionalTextEdits = {
                {
                  newText = "!",
                  range = { start = { line = 0, character = 3 }, ["end"] = { line = 0, character = 3 } },
                },
              },
            },
          }
        or {}
      callback(nil, { isIncomplete = false, items = items })
      return true, 67
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local initial
  Bridge.complete(params, function(_, value)
    initial = value
  end)
  t.assert_eq("local function", initial.items[1].label, "initial upstream item")
  t.assert_eq(2, initial.items[1]._era_cmp_suffix_bytes, "initial suffix")

  for _, value in ipairs({ "lf", "lfu" }) do
    query = value
    vim.api.nvim_set_current_line(value .. "ZZ")
    vim.api.nvim_win_set_cursor(0, { 1, #value })
    params.position.character = #value
    params.context = {
      triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerForIncompleteCompletions,
    }
    local extended
    Bridge.complete(params, function(_, result)
      extended = result
    end)
    t.assert_eq("local function", extended.items[1].label, "retained item for " .. value)
    t.assert_eq(2, extended.items[1]._era_cmp_suffix_bytes, "retargeted suffix for " .. value)
    t.assert_eq(#value + 2, extended.items[1].additionalTextEdits[1].range.start.character, "following edit")
  end
  t.assert_eq(1, requests, "complete client request count")

  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("incomplete refresh requests only incomplete clients", function()
  local bufnr, params = context("it")
  local_result.items = {}
  local requests = { [71] = 0, [72] = 0 }
  local function client(id, incomplete)
    return {
      id = id,
      name = "lsp-" .. id,
      offset_encoding = "utf-8",
      request = function(_, _, _, callback)
        requests[id] = requests[id] + 1
        callback(nil, {
          isIncomplete = incomplete,
          items = {
            {
              label = "item-" .. id,
              textEdit = {
                newText = "item-" .. id,
                range = { start = { line = 0, character = 0 }, ["end"] = params.position },
              },
            },
          },
        })
        return true, id
      end,
    }
  end
  t:patch_table(vim.lsp, "get_clients", function()
    return { client(71, false), client(72, true) }
  end)

  Bridge.complete(params, function() end)
  vim.api.nvim_set_current_line("ite")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  params.position.character = 3
  params.context = {
    triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerForIncompleteCompletions,
  }
  local refreshed
  Bridge.complete(params, function(_, value)
    refreshed = value
  end)

  t.assert_eq(1, requests[71], "complete client")
  t.assert_eq(2, requests[72], "incomplete client")
  t.assert_eq(2, #refreshed.items, "deduplicated refreshed items")
  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("incomplete refresh publishes cached items before a slow provider settles", function()
  local bufnr, params = context("it")
  local_result.items = {}
  local requests = 0
  local respond = nil ---@type function|nil
  local client = {
    id = 74,
    name = "cached-incomplete-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      requests = requests + 1
      if requests == 1 then
        callback(nil, { isIncomplete = true, items = { { label = "item" } } })
      else
        respond = callback
      end
      return true, requests
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local initial
  Bridge.complete(params, function(_, value)
    initial = value
  end)
  t.assert_eq("item", initial.items[1].label, "initial item")

  vim.api.nvim_set_current_line("ite")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  params.position.character = 3
  params.context = {
    triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerForIncompleteCompletions,
  }
  local refreshed
  Bridge.complete(params, function(_, value)
    refreshed = value
  end)

  t.assert_eq(2, requests, "incomplete provider request")
  t.assert_eq("item", assert(refreshed).items[1].label, "cached refresh item")
  t.assert_true(type(respond) == "function", "slow provider remains pending")
  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("retargets cached zero-length insertion ranges past new input", function()
  local bufnr, params = context("foo")
  local_result.items = {}
  local query = "foo"
  local client = {
    id = 70,
    name = "insertion-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      local items = query == "foo"
          and {
            {
              label = "fooBar",
              textEdit = {
                newText = "Bar",
                range = { start = { line = 0, character = 3 }, ["end"] = { line = 0, character = 3 } },
              },
            },
          }
        or {}
      callback(nil, { isIncomplete = false, items = items })
      return true, 70
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local initial
  Bridge.complete(params, function(_, value)
    initial = value
  end)
  t.assert_eq("fooBar", initial.items[1].textEdit.newText, "initial insertion")

  query = "foox"
  vim.api.nvim_set_current_line(query)
  vim.api.nvim_win_set_cursor(0, { 1, #query })
  params.position.character = #query
  local extended
  Bridge.complete(params, function(_, value)
    extended = value
  end)
  t.assert_eq("fooxBar", extended.items[1].textEdit.newText, "new input is preserved")
  local origin_range = extended.items[1]._era_cmp_origin.item.textEdit.range
  t.assert_eq(3, origin_range.start.character, "immutable upstream insertion start")
  t.assert_eq(3, origin_range["end"].character, "immutable upstream insertion end")

  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("late superseded responses join the current token cache", function()
  local bufnr, params = context("l")
  local_result.items = {}
  local responses = {} ---@type table<string, function>
  local client = {
    id = 68,
    name = "late-cached-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      responses[vim.api.nvim_get_current_line()] = callback
      return true, #responses + 1
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  Bridge.complete(params, function() end)
  vim.api.nvim_set_current_line("lfu")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  params.position.character = 3
  local current
  Bridge.complete(params, function(_, value)
    current = value
  end)

  assert(responses.l)(nil, {
    items = {
      {
        label = "local function",
        textEdit = {
          newText = "local function",
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 1 } },
        },
      },
    },
  })
  assert(responses.lfu)(nil, { items = {} })

  t.assert_eq("local function", current.items[1].label, "late retained item")
  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("late superseded responses cannot replace a newer candidate", function()
  local bufnr, params = context("l")
  local_result.items = {}
  local responses = {} ---@type table<string, function>
  local client = {
    id = 69,
    name = "versioned-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      responses[vim.api.nvim_get_current_line()] = callback
      return true, #responses + 1
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  Bridge.complete(params, function() end)
  vim.api.nvim_set_current_line("lfu")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  params.position.character = 3
  Bridge.complete(params, function() end)

  assert(responses.lfu)(nil, {
    isIncomplete = true,
    items = {
      {
        label = "local function",
        data = { version = "new" },
        textEdit = {
          newText = "local function",
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
        },
      },
    },
  })
  assert(responses.l)(nil, {
    isIncomplete = false,
    items = {
      {
        label = "local function",
        data = { version = "old" },
        textEdit = {
          newText = "local function",
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 1 } },
        },
      },
    },
  })

  local final
  Bridge.complete(params, function(_, value)
    final = value
  end)
  t.wait_until(function()
    return final ~= nil
  end, 1000, "cached current response")
  t.assert_eq("new", final.items[1].data.version, "preferred current response")

  vim.api.nvim_set_current_line("lfut")
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  params.position.character = 4
  params.context = {
    triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerForIncompleteCompletions,
  }
  Bridge.complete(params, function() end)
  t.assert_true(responses.lfut ~= nil, "newer incomplete response remains refreshable")
  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("preserves same-label LSP overloads with distinct semantics", function()
  local bufnr, params = context("pri")
  local_result.items = {}
  local client = {
    id = 71,
    name = "overload-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      callback(nil, {
        items = {
          {
            label = "print",
            kind = vim.lsp.protocol.CompletionItemKind.Function,
            detail = "print(value: string)",
            textEdit = {
              newText = "print",
              range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
            },
            data = { overload = "string" },
          },
          {
            label = "print",
            kind = vim.lsp.protocol.CompletionItemKind.Function,
            detail = "print(value: number)",
            textEdit = {
              newText = "print",
              range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
            },
            command = { title = "number", command = "overload.number" },
            data = { overload = "number" },
          },
        },
      })
      return true, 71
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local result
  Bridge.complete(params, function(_, value)
    result = value
  end)

  t.assert_eq(2, #result.items, "overload count")
  t.assert_eq("print(value: string)", result.items[1].detail, "string overload")
  t.assert_eq("print(value: number)", result.items[2].detail, "number overload")
  t.assert_nil(result.items[1]._era_cmp_meta.usage_key, "unused identity remains lazy")
  t.assert_nil(result.items[2]._era_cmp_meta.usage_key, "unused overload identity remains lazy")
  local string_key = Bridge.get_usage_key(result.items[1])
  local number_key = Bridge.get_usage_key(result.items[2])
  t.assert_false(string_key == number_key, "overload usage identity")
  Bridge.set_history({
    [number_key] = { count = 12, last_used = os.time() },
  })
  Bridge.complete(params, function(_, value)
    result = value
  end)
  t.assert_eq("print(value: number)", result.items[1].detail, "overload-specific frecency")
  Bridge.set_history({})
  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("canonicalizes LSP usage identity defaults and structured payloads", function()
  local function key(item)
    return Bridge.get_usage_key({
      _era_cmp_meta = { source = "identity-lsp" },
      _era_cmp_origin = { item = item },
    })
  end

  local omitted = {
    label = "value",
    kind = vim.lsp.protocol.CompletionItemKind.Function,
  }
  local explicit = {
    label = "value",
    kind = vim.lsp.protocol.CompletionItemKind.Function,
    filterText = "value",
    sortText = "value",
    insertText = "value",
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
  }
  t.assert_eq(key(omitted), key(explicit), "effective defaults")

  local left_options = { alpha = 1, beta = 2 }
  local right_options = {}
  right_options.beta = 2
  right_options.alpha = 1
  local command_left = vim.tbl_extend("force", vim.deepcopy(omitted), {
    command = { title = "run", command = "identity.run", arguments = { left_options } },
  })
  local command_reordered = vim.tbl_extend("force", vim.deepcopy(omitted), {
    command = { title = "run", command = "identity.run", arguments = { right_options } },
  })
  local command_right = vim.tbl_extend("force", vim.deepcopy(omitted), {
    command = { title = "run", command = "identity.run", arguments = { { alpha = 1, beta = 3 } } },
  })
  t.assert_eq(key(command_left), key(command_reordered), "canonical command map order")
  t.assert_false(key(command_left) == key(command_right), "command arguments")

  local function with_edit(text, character)
    return vim.tbl_extend("force", vim.deepcopy(omitted), {
      additionalTextEdits = {
        {
          newText = text,
          range = {
            start = { line = 0, character = character },
            ["end"] = { line = 0, character = character },
          },
        },
      },
    })
  end
  t.assert_false(key(with_edit("import A", 0)) == key(with_edit("import B", 0)), "additional edit text")
  t.assert_eq(key(with_edit("import A", 0)), key(with_edit("import A", 2)), "position-only edit change")

  local function with_edits(first, second)
    return vim.tbl_extend("force", vim.deepcopy(omitted), {
      additionalTextEdits = {
        {
          newText = first,
          range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 0 } },
        },
        {
          newText = second,
          range = { start = { line = 2, character = 0 }, ["end"] = { line = 2, character = 0 } },
        },
      },
    })
  end
  t.assert_false(
    key(with_edits("import A", "import B")) == key(with_edits("import B", "import A")),
    "edit target order"
  )
end)

t:test("deduplicates canonical defaults while preserving command and edit overloads", function()
  local bufnr, params = context("val")
  vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, { "", "" })
  local_result.items = {}
  local base = {
    label = "value",
    kind = vim.lsp.protocol.CompletionItemKind.Function,
  }
  local items = {
    vim.deepcopy(base),
    vim.tbl_extend("force", vim.deepcopy(base), {
      filterText = "value",
      sortText = "value",
      insertText = "value",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    }),
    vim.tbl_extend("force", vim.deepcopy(base), {
      command = { title = "run", command = "identity.run", arguments = { "left" } },
    }),
    vim.tbl_extend("force", vim.deepcopy(base), {
      command = { title = "run", command = "identity.run", arguments = { "right" } },
    }),
    vim.tbl_extend("force", vim.deepcopy(base), {
      additionalTextEdits = {
        {
          newText = "import A",
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
        },
      },
    }),
    vim.tbl_extend("force", vim.deepcopy(base), {
      additionalTextEdits = {
        {
          newText = "import A",
          range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 0 } },
        },
      },
    }),
    vim.tbl_extend("force", vim.deepcopy(base), {
      additionalTextEdits = {
        {
          newText = "import B",
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
        },
      },
    }),
    vim.tbl_extend("force", vim.deepcopy(base), {
      additionalTextEdits = {
        {
          newText = "import A",
          range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 0 } },
        },
        {
          newText = "import B",
          range = { start = { line = 2, character = 0 }, ["end"] = { line = 2, character = 0 } },
        },
      },
    }),
    vim.tbl_extend("force", vim.deepcopy(base), {
      additionalTextEdits = {
        {
          newText = "import B",
          range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 0 } },
        },
        {
          newText = "import A",
          range = { start = { line = 2, character = 0 }, ["end"] = { line = 2, character = 0 } },
        },
      },
    }),
  }
  local client = {
    id = 74,
    name = "identity-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      callback(nil, { items = items })
      return true, 74
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local result
  Bridge.complete(params, function(_, value)
    result = value
  end)
  t.assert_eq(8, #result.items, "canonical overload count")
  local keys = {} ---@type table<string, boolean>
  local position_keys = {} ---@type string[]
  local repeated_keys = 0
  for _, item in ipairs(result.items) do
    local usage_key = Bridge.get_usage_key(item)
    local edits = item.additionalTextEdits or {}
    if #edits == 1 and edits[1].newText == "import A" then
      position_keys[#position_keys + 1] = usage_key
    end
    if keys[usage_key] then
      repeated_keys = repeated_keys + 1
    end
    keys[usage_key] = true
  end
  t.assert_eq(2, #position_keys, "position-only overload count")
  t.assert_eq(position_keys[1], position_keys[2], "position-insensitive usage identity")
  t.assert_eq(1, repeated_keys, "position-only overloads share usage identity")
  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("registers known client-side completion commands", function()
  local parameter_hints = "editor.action.triggerParameterHints"
  local trigger_suggest = "editor.action.triggerSuggest"
  t:patch_table(vim.lsp.commands, parameter_hints, nil)
  t:patch_table(vim.lsp.commands, trigger_suggest, nil)

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  local signature_bufnr
  local show_count = 0
  Bridge.register_commands(function()
    show_count = show_count + 1
  end, function(value)
    signature_bufnr = value
    return true
  end)

  vim.lsp.commands[parameter_hints]({ title = "test", command = parameter_hints }, { bufnr = bufnr })
  vim.lsp.commands[trigger_suggest]({ title = "test", command = trigger_suggest }, { bufnr = bufnr })
  t.wait_until(function()
    return signature_bufnr ~= nil and show_count == 1
  end, 1000, "scheduled client commands")
  t.assert_eq(bufnr, signature_bufnr, "signature buffer")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("cancellation suppresses late upstream responses", function()
  local bufnr, params = context("value")
  local_result.items = {}
  local response
  local cancel_count = 0
  local client = {
    id = 44,
    name = "slow-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      response = callback
      return true, 9
    end,
    cancel_request = function(_, request_id)
      t.assert_eq(9, request_id, "request id")
      cancel_count = cancel_count + 1
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)

  local completion_count = 0
  local cancel = Bridge.complete(params, function()
    completion_count = completion_count + 1
  end)
  cancel()
  response(nil, { items = { { label = "late" } } })

  t.assert_eq(1, cancel_count, "upstream cancellation")
  t.assert_eq(0, completion_count, "cancelled before initial publication")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("resolve send failure falls back synchronously", function()
  local bufnr, params = context("value")
  local_result.items = {}
  local client = {
    id = 47,
    name = "stopped-lsp",
    offset_encoding = "utf-8",
    supports_method = function()
      return true
    end,
    request = function(_, method, _, callback)
      if method == "textDocument/completion" then
        callback(nil, { items = { { label = "value" } } })
        return true, 12
      end
      return false, nil
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)

  local completion
  Bridge.complete(params, function(_, value)
    completion = assert(value).items[1]
  end)
  local resolved
  Bridge.resolve(completion, function(err, value)
    t.assert_nil(err, "resolve error")
    resolved = value
  end)
  t.assert_eq(completion, resolved, "fallback item")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("invalid upstream item does not discard healthy local results", function()
  local bufnr, params = context("value")
  local_result.items = {
    {
      label = "value",
      data = { era_cmp = { source = "buffer", priority = 100, score = 100, exact = false } },
    },
  }
  local client = {
    id = 49,
    name = "broken-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      callback(nil, { items = { { label = "broken", textEdit = true } } })
      return true, 14
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local result
  Bridge.complete(params, function(err, value)
    t.assert_nil(err, "completion error")
    result = value
  end)
  t.assert_eq(1, #result.items, "healthy item count")
  t.assert_eq("value", result.items[1].label, "healthy item")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("invalid upstream siblings do not discard a healthy candidate", function()
  local bufnr, params = context("val")
  local_result.items = {}
  local client = {
    id = 70,
    name = "partially-broken-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      callback(nil, {
        itemDefaults = {
          editRange = {
            start = { line = 0, character = 0 },
            ["end"] = { line = 0, character = 3 },
          },
        },
        items = {
          { label = "value", textEditText = "value" },
          { label = "bad-kind", kind = {} },
          { label = "bad-default", textEdit = true },
        },
      })
      return true, 70
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local result
  Bridge.complete(params, function(err, value)
    t.assert_nil(err, "completion error")
    result = value
  end)

  t.assert_eq(1, #result.items, "healthy sibling count")
  t.assert_eq("value", result.items[1].label, "healthy sibling")
  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("rejects malformed fields before native conversion", function()
  local bufnr, params = context("value")
  local_result.items = {
    {
      label = "value",
      data = { era_cmp = { source = "buffer", priority = 100, score = 100, exact = false } },
    },
  }
  local client = {
    id = 50,
    name = "malformed-fields",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      callback(nil, {
        items = {
          { label = "bad-tags", tags = true },
          { label = "bad-sort", sortText = {} },
          {
            label = "bad-snippet",
            insertText = "${1",
            insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
          },
          {
            label = "bad-overlap",
            textEdit = {
              newText = "value",
              range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 5 } },
            },
            additionalTextEdits = {
              {
                newText = "x",
                range = { start = { line = 0, character = 2 }, ["end"] = { line = 0, character = 3 } },
              },
            },
          },
          {
            label = "bad-mutual-overlap",
            additionalTextEdits = {
              {
                newText = "x",
                range = { start = { line = 0, character = 6 }, ["end"] = { line = 0, character = 9 } },
              },
              {
                newText = "y",
                range = { start = { line = 0, character = 8 }, ["end"] = { line = 0, character = 10 } },
              },
            },
          },
        },
      })
      return true, 15
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local result
  Bridge.complete(params, function(err, value)
    t.assert_nil(err, "completion error")
    result = value
  end)
  t.assert_eq(1, #result.items, "healthy item count")
  t.assert_eq("value", result.items[1].label, "healthy item")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("rejects an item when any additional edit cannot be converted", function()
  local bufnr, params = context("value")
  local_result.items = {
    {
      label = "value",
      data = { era_cmp = { source = "buffer", priority = 100, score = 100, exact = false } },
    },
  }
  local client = {
    id = 51,
    name = "partial-edits",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      callback(nil, {
        items = {
          {
            label = "partial",
            additionalTextEdits = {
              {
                newText = "valid",
                range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
              },
              {
                newText = "invalid",
                range = { start = { line = 99, character = 0 }, ["end"] = { line = 99, character = 0 } },
              },
            },
          },
        },
      })
      return true, 16
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local result
  Bridge.complete(params, function(err, value)
    t.assert_nil(err, "completion error")
    result = value
  end)
  t.assert_eq(1, #result.items, "healthy item count")
  t.assert_eq("value", result.items[1].label, "healthy item")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("superseded sessions retain deadline cancellation", function()
  local bufnr, params = context("l")
  local_result.items = {}
  local callbacks = {} ---@type table<integer, function>
  local cancelled = {} ---@type table<integer, boolean>
  local next_request_id = 0
  local client = {
    id = 52,
    name = "superseded-hung-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      next_request_id = next_request_id + 1
      callbacks[next_request_id] = callback
      return true, next_request_id
    end,
    cancel_request = function(_, request_id)
      cancelled[request_id] = true
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)

  Bridge.complete(params, function() end)
  vim.api.nvim_set_current_line("lf")
  vim.api.nvim_win_set_cursor(0, { 1, 2 })
  params.position.character = 2
  Bridge.complete(params, function() end)

  t.wait_until(function()
    return cancelled[1] == true
  end, 2500, "superseded deadline")
  callbacks[1](nil, { items = { { label = "late" } } })
  t.assert_true(cancelled[1], "superseded request cancellation")
  Bridge.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("completion deadline retains the local-first result and cancels stalled clients", function()
  local bufnr, params = context("value")
  local_result.items = {
    {
      label = "value",
      data = { era_cmp = { source = "buffer", priority = 100, score = 100, exact = false } },
    },
  }
  local cancel_count = 0
  defer_local = true
  local client = {
    id = 48,
    name = "hung-lsp",
    offset_encoding = "utf-8",
    request = function()
      return true, 13
    end,
    cancel_request = function(_, request_id)
      t.assert_eq(13, request_id, "request id")
      cancel_count = cancel_count + 1
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return client
  end)

  refreshes = {}
  local started = vim.uv.hrtime()
  local result
  Bridge.complete(params, function(err, value)
    t.assert_nil(err, "completion error")
    result = value
  end)
  t.wait_until(function()
    return result ~= nil
  end, 1000, "bounded local-first result")
  local elapsed_ms = (vim.uv.hrtime() - started) / 1e6
  t.assert_true(elapsed_ms < 100, string.format("local-first latency %.1fms", elapsed_ms))
  t.assert_eq("value", result.items[1].label, "local item")
  t.wait_until(function()
    return cancel_count == 1 and #refreshes == 1
  end, 2500, "deadline refresh")
  t.assert_eq(1, cancel_count, "stalled cancellation")
  local final
  Bridge.complete(params, function(_, value)
    final = value
  end)
  t.assert_eq("value", final.items[1].label, "final local item")
  defer_local = false
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("escapes normalized literal prefixes for snippets", function()
  local line = "$foo.as"
  local bufnr, params = context(line)
  local_result.items = {
    {
      label = "async",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      textEdit = {
        newText = "async(${1:value})",
        range = { start = { line = 0, character = 5 }, ["end"] = params.position },
      },
      data = { era_cmp = { source = "snippets", priority = 200, score = 200, exact = false } },
    },
  }
  local client = {
    id = 45,
    name = "wide-range-lsp",
    offset_encoding = "utf-8",
    request = function(_, _, _, callback)
      callback(nil, {
        items = {
          {
            label = "$foo.async",
            textEdit = {
              newText = "$foo.async",
              range = { start = { line = 0, character = 0 }, ["end"] = params.position },
            },
          },
        },
      })
      return true, 10
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)

  local result
  Bridge.complete(params, function(_, value)
    result = value
  end)
  local snippet = assert(vim.iter(result.items):find(function(item)
    return item.data and item.data.era_cmp and item.data.era_cmp.source == "snippets"
  end))
  t.assert_eq("\\$foo.async(${1:value})", snippet.textEdit.newText, "escaped prefix")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
