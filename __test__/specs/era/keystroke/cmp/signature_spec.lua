local harness = require("__test__.support.harness")
local runtime = require("__test__.support.cmp.runtime")
runtime.setup()
local t = harness.new()
local Context = require("era.keystroke.cmp.context")
local Signature = require("era.keystroke.cmp.signature")

---@return table
local function fixture()
  local bufnr = t:buffer(nil, { listed = true, current = true })
  local state = {
    signature = Signature.new(),
    clients = {},
    requests = {},
    response = {
      activeParameter = 0,
      signatures = { { label = "foo(foo)", parameters = { { label = "foo" } }, documentation = "original docs" } },
    },
  }
  t:defer(function()
    state.signature:destroy()
  end)
  t:patch_table(Context, "capture", function()
    return state.context
  end)
  t:patch_table(vim.lsp, "get_clients", function()
    return state.clients
  end)

  ---@param provider                    lsp.SignatureHelpOptions
  ---@return nil
  function state:add_client(provider)
    local client = {
      id = #self.clients + 1,
      offset_encoding = "utf-16",
      server_capabilities = { signatureHelpProvider = provider },
      request = function(client, method, params, callback)
        t.assert_eq("textDocument/signatureHelp", method)
        self.requests[#self.requests + 1] = { client = client.id, params = params, callback = callback }
        if self.reject then
          return false
        end
        if not self.delay then
          callback(nil, self.response)
        end
        return true, #self.requests
      end,
      cancel_request = function() end,
    }
    self.clients[#self.clients + 1] = client
  end

  ---@param line                        string
  ---@param force                       ?boolean
  ---@return boolean
  function state:update(line, force)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { line })
    self.context = runtime.context(line)
    return self.signature:update(self.context, force)
  end

  ---@param count                       integer
  ---@return nil
  function state:wait(count)
    t.wait_until(function()
      return #self.requests == count
    end, 5000, "signature requests sent")
  end
  return state
end

t:test("manual signature requests omit the character and share the pre-request active state", function()
  local state = fixture()
  state:add_client({ triggerCharacters = { "(" } })
  state:add_client({ triggerCharacters = { "[" } })
  t.assert_true(state:update("foo(", true))
  state:wait(2)
  for _, request in ipairs(state.requests) do
    t.assert_eq(1, request.params.context.triggerKind, "Invoked")
    t.assert_nil(request.params.context.triggerCharacter)
    t.assert_eq(false, request.params.context.isRetrigger, "synchronous responses do not change later requests")
    t.assert_nil(request.params.context.activeSignatureHelp)
  end
end)

t:test("automatic signature triggers are per client and retrigger characters cannot open a signature", function()
  local state = fixture()
  state:add_client({ triggerCharacters = { "(" }, retriggerCharacters = { "," } })
  state:add_client({ triggerCharacters = { "[" }, retriggerCharacters = { ";" } })
  t.assert_eq(false, state:update("foo,"), "retrigger character alone does not open the window")
  t.assert_eq(false, state:update("foo;"), "other client's retrigger character also needs active help")
  t.assert_true(state:update("foo("))
  state:wait(1)
  local request = state.requests[1]
  t.assert_eq(1, request.client, "only the client advertising this trigger is queried")
  t.assert_eq(2, request.params.context.triggerKind)
  t.assert_eq("(", request.params.context.triggerCharacter)
  t.assert_eq(false, request.params.context.isRetrigger)
  local marks = vim.api.nvim_buf_get_extmarks(state.signature.bufnr, -1, 0, -1, { details = true })
  t.assert_eq(1, #marks, "response carries its client's trigger characters to rendering")
  t.assert_eq(4, marks[1][3], "parameter starts after the opening parenthesis")
  t.assert_eq(7, marks[1][4].end_col)
end)

t:test("active signatures use ContentChange for ordinary input and per-client retrigger characters", function()
  local state = fixture()
  state:add_client({ triggerCharacters = { "(" }, retriggerCharacters = { "," } })
  state:add_client({ triggerCharacters = { "[" }, retriggerCharacters = { ";" } })
  state:update("foo(", true)
  state:wait(2)
  local original = vim.deepcopy(state.response)
  state:update("foo(a")
  state:wait(4)
  for index = 3, 4 do
    local context = state.requests[index].params.context
    t.assert_eq(3, context.triggerKind, "ContentChange")
    t.assert_nil(context.triggerCharacter)
    t.assert_eq(true, context.isRetrigger)
    t.assert_same(original, context.activeSignatureHelp, "complete response is preserved")
  end
  state:update("foo(a,")
  state:wait(6)
  t.assert_eq(2, state.requests[5].params.context.triggerKind)
  t.assert_eq(",", state.requests[5].params.context.triggerCharacter)
  t.assert_eq(3, state.requests[6].params.context.triggerKind, "unadvertised character is a content change")
  t.assert_nil(state.requests[6].params.context.triggerCharacter)
  state:update("foo(a,", true)
  state:wait(8)
  for index = 7, 8 do
    t.assert_eq(1, state.requests[index].params.context.triggerKind, "manual retrigger remains Invoked")
    t.assert_nil(state.requests[index].params.context.triggerCharacter)
  end
  t.assert_same(original, state.response, "rendering never rewrites protocol fields")
end)

t:test("cancelled signature responses cannot reopen the window", function()
  local state = fixture()
  state:add_client({ triggerCharacters = { "(" } })
  state.delay = true
  state:update("foo(")
  state:wait(1)
  state.signature:hide()
  state.requests[1].callback(nil, state.response)
  t.assert_nil(state.signature.winnr)
end)

t:test("failed request submission clears stale signature help", function()
  local state = fixture()
  state:add_client({ triggerCharacters = { "(" } })
  state:update("foo(")
  state:wait(1)
  t.assert_true(vim.api.nvim_win_is_valid(assert(state.signature.winnr)))
  state.reject = true
  state:update("foo(a")
  state:wait(2)
  t.assert_nil(state.signature.winnr)
  t.assert_eq(false, state:update("foo(ab"), "failed refresh releases the active state")
end)

t:test("numeric signature parameter offsets are UTF-16 regardless of client encoding", function()
  local signature = Signature.new()
  t:defer(function()
    signature:destroy()
  end)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "call(" })
  signature:render(runtime.context("call("), {
    activeSignature = 0,
    activeParameter = 0,
    signatures = { { label = "call(😀 value)", parameters = { { label = { 8, 13 } } } } },
  })
  local bufnr = signature.bufnr
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true })
  t.assert_eq(1, #marks, "active parameter")
  local mark = marks[1]
  local text = vim.api.nvim_buf_get_lines(bufnr, mark[2], mark[2] + 1, false)[1]
  t.assert_eq("value", text:sub(mark[3] + 1, mark[4].end_col), "highlighted parameter")
end)

t:test("string signature parameters start after the server's trigger characters", function()
  local signature = Signature.new()
  t:defer(function()
    signature:destroy()
  end)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foo(" })
  for _, example in ipairs({
    { label = "foo(foo)", parameter = 0, start_col = 4, end_col = 7 },
    { label = "(foo)", parameter = 0, start_col = 1, end_col = 4 },
    { label = "pkg.foo(foo)", parameter = 0, start_col = 8, end_col = 11 },
    { label = "foo(foo, foo)", parameter = 1, start_col = 9, end_col = 12 },
  }) do
    local parameters = { { label = "foo" } }
    if example.parameter == 1 then
      parameters[2] = { label = "foo" }
    end
    signature:render(runtime.context("foo("), {
      activeParameter = example.parameter,
      signatures = { { label = example.label, parameters = parameters } },
    }, { "(", "," })
    local marks = vim.api.nvim_buf_get_extmarks(signature.bufnr, -1, 0, -1, {
      details = true,
    })
    t.assert_eq(1, #marks, example.label)
    t.assert_eq(0, marks[1][2], "plain signature label row")
    t.assert_eq(example.start_col, marks[1][3], "parameter start")
    t.assert_eq(example.end_col, marks[1][4].end_col, "parameter end")
  end
end)

t:test("signature nulls and overload projection preserve the server response", function()
  local signature = Signature.new()
  t:defer(function()
    signature:destroy()
  end)
  local context = runtime.context("call(")
  vim.api.nvim_buf_set_lines(context.bufnr, 0, -1, false, { context.line })
  local result = vim.json.decode([[
    {"activeSignature":null,"activeParameter":null,
     "signatures":[{"label":"call(value)","parameters":null,"documentation":null}]}
  ]])
  local original = vim.deepcopy(result)
  signature:render(context, result)
  t.assert_true(vim.api.nvim_win_is_valid(assert(signature.winnr)), "nullable signature is displayed")
  t.assert_eq(0, #vim.api.nvim_buf_get_extmarks(signature.bufnr, -1, 0, -1, {}))
  t.assert_same(original, result, "nullable response is immutable")

  result = {
    activeSignature = 1,
    activeParameter = 0,
    signatures = {
      { label = "unused()", parameters = vim.NIL, documentation = { kind = "markdown", value = "unused docs" } },
      { label = "call(😀 value)", parameters = { { label = { 8, 13 }, documentation = "parameter docs" } } },
    },
  }
  original = vim.deepcopy(result)
  signature:render(context, result)
  local bufnr = assert(signature.bufnr)
  t.assert_eq("call(😀 value)", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "selected overload")
  t.assert_eq(1, vim.api.nvim_buf_line_count(bufnr), "unselected overload and documentation are omitted")
  local mark = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true })[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, mark[2], mark[2] + 1, false)[1]
  t.assert_eq("value", line:sub(mark[3] + 1, mark[4].end_col), "UTF-16 parameter remains highlighted")
  t.assert_same(original, result, "retrigger response retains original offsets and documentation")
end)

t:test("signature explicit null overrides the response active parameter", function()
  local signature = Signature.new()
  t:defer(function()
    signature:destroy()
  end)
  for _, example in ipairs({ { count = 1 }, { active = vim.NIL, count = 0 }, { active = 0, count = 1 } }) do
    local result = {
      activeParameter = 0,
      signatures = { { label = "call(value)", activeParameter = example.active, parameters = { { label = "value" } } } },
    }
    local before = vim.deepcopy(result)
    signature:render(runtime.context("call("), result, { "(" })
    local marks = vim.api.nvim_buf_get_extmarks(signature.bufnr, -1, 0, -1, {})
    t.assert_eq(example.count, #marks, "only a missing signature field inherits the response value")
    t.assert_same(before, result, "explicit null remains available to retrigger requests")
  end
end)

t:test("signature ranges cover label boundaries, multiline text and mixed parameter labels", function()
  local signature = Signature.new()
  t:defer(function()
    signature:destroy()
  end)
  for _, example in ipairs({
    {
      label = "entire label",
      parameters = { { label = { 0, 12 } } },
      row = 0,
      col = 0,
      finish = 12,
      text = "entire label",
    },
    {
      label = "foo(\n  😀 value\n)",
      parameters = { { label = { 10, 15 } } },
      row = 1,
      col = 7,
      finish = 12,
      text = "value",
    },
    {
      label = "foo(a, b)",
      activeParameter = 1,
      parameters = { { label = { 4, 5 } }, { label = "b" } },
      row = 0,
      col = 7,
      finish = 8,
      text = "b",
    },
  }) do
    signature:render(runtime.context("foo("), { activeParameter = 0, signatures = { example } }, { "(", "," })
    local bufnr = assert(signature.bufnr)
    local mark = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true })[1]
    t.assert_true(mark ~= nil, example.label)
    t.assert_eq(example.row, mark[2])
    t.assert_eq(example.col, mark[3])
    t.assert_eq(example.finish, mark[4].end_col)
    local line = vim.api.nvim_buf_get_lines(bufnr, mark[2], mark[2] + 1, false)[1]
    t.assert_eq(example.text, line:sub(mark[3] + 1, mark[4].end_col), "highlight covers the intended parameter")
  end
end)

t:test("plain signatures wrap wide characters and reuse only their text", function()
  local signature = Signature.new()
  t:defer(function()
    signature:destroy()
  end)
  local context = runtime.context("call(")
  vim.api.nvim_buf_set_lines(context.bufnr, 0, -1, false, { context.line })
  local width = math.min(88, vim.o.columns - 4)
  local label = "a" .. ("中"):rep(width - 1) .. "b"
  signature:render(context, { signatures = { { label = label } } })
  t.assert_eq(width, vim.api.nvim_win_get_width(signature.winnr))
  t.assert_eq(3, vim.api.nvim_win_get_height(signature.winnr), "wide characters wrap without Markdown fence rows")
  local tick = vim.api.nvim_buf_get_changedtick(signature.bufnr)
  signature:hide()
  signature:render(context, { signatures = { { label = label } } })
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(signature.bufnr), "reopening does not rewrite identical text")
  t.assert_eq(3, vim.api.nvim_win_get_height(signature.winnr))
  signature:render(context, { signatures = { { label = "short()" } } })
  t.assert_eq(1, vim.api.nvim_win_get_height(signature.winnr), "short content has no cached or fenced padding")
end)

t:run()
