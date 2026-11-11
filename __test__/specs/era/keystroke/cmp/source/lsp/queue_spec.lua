local harness = require("__test__.support.harness")
local runtime = require("__test__.support.cmp.runtime")
local fixture = require("__test__.support.cmp.fixture")
runtime.setup()
local t = harness.new()
local Lsp = require("era.keystroke.cmp.source.lsp")

---@param count                         integer
---@return table
local function pending_lsp(count)
  fixture.buffer(t, { "" })
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
  end, 5000, "stuck transport yields to the latest query")
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
  end, 5000, "source timeout publishes fallback eligibility")
  t.assert_eq(false, result.pending, "timeout releases the fallback dependency")
  t.assert_true(result.incomplete, "pending server response remains retryable")
  callback(nil, { items = { { label = "alpha" } }, isIncomplete = false })
  t.assert_eq("alpha", result.items[1].raw.label, "late response for the active request is still useful")
end)

t:run()
