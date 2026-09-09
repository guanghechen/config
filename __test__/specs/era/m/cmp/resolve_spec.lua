local harness = require("__test__.support.harness")
local protocol = require("era.m.cmp.protocol")
local resolver = require("era.m.cmp.resolve")
local suite = harness.new("era.m.cmp.resolve")

---@return table
local function fixture()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "", "al tail" })
  suite:defer(function()
    resolver.clear(bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  local state = { requests = {}, cancellations = {}, timers = {}, reports = {} }
  suite:patch_global("stl", {
    reporter = {
      error = function(value)
        state.reports[#state.reports + 1] = value
      end,
      warn = function(value)
        state.reports[#state.reports + 1] = value
      end,
    },
  })
  suite:patch_table(vim, "defer_fn", function(callback, timeout)
    local timer = { callback = callback, timeout = timeout, closed = false }
    timer.is_closing = function()
      return timer.closed
    end
    timer.stop = function() end
    timer.close = function()
      timer.closed = true
    end
    state.timers[#state.timers + 1] = timer
    return timer
  end)
  state.client = {
    id = 42,
    name = "resolve-spec",
    offset_encoding = "utf-8",
    supports_method = function()
      return true
    end,
    request = function(_, method, item, callback, request_bufnr)
      suite.assert_eq("completionItem/resolve", method, "RPC method")
      suite.assert_eq(bufnr, request_bufnr, "request buffer")
      state.requests[#state.requests + 1] = { item = item, callback = callback }
      return true, #state.requests
    end,
    cancel_request = function(_, request_id)
      state.cancellations[#state.cancellations + 1] = request_id
    end,
  }
  suite:patch_table(vim.lsp, "get_client_by_id", function()
    return state.client
  end)
  state.context =
    { bufnr = bufnr, row = 1, col = 2, line = "al tail", start_col = 0, end_col = 2, keyword = "al", filetype = "lua" }
  state.raw = { label = "alpha", data = { id = 1 } }
  state.candidate = { item = state.raw, context = state.context }
  state.item =
    protocol.normalize(state.raw, state.context, 0, 0, 0, nil, state.client, nil, nil, state.context, state.candidate)
  state.bufnr = bufnr
  return state
end

suite:test("documentation and acceptance share one in-flight resolve and its full result", function()
  local state = fixture()
  local documentation
  local accepted
  local cancel_documentation = resolver.request(state.item, function(_, result)
    documentation = result
  end)
  resolver.request(state.item, function(_, result)
    accepted = result
  end)
  suite.assert_eq(1, #state.requests, "shared RPC")
  cancel_documentation()
  suite.assert_eq(0, #state.cancellations, "acceptance keeps the RPC alive")
  local edits = {
    {
      newText = "import alpha\n",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
    },
  }
  state.requests[1].callback(
    nil,
    { documentation = "Alpha docs", additionalTextEdits = edits, command = { command = "alpha.import" } }
  )
  suite.assert_nil(documentation, "cancelled listener")
  suite.assert_eq("Alpha docs", accepted.documentation, "documentation result")
  suite.assert_eq("import alpha\n", accepted.additionalTextEdits[1].newText, "acceptance receives imports")
  suite.assert_true(accepted.command ~= nil, "acceptance receives commands")
  suite.assert_nil(state.raw.documentation, "transport snapshot stays immutable")
  suite.assert_true(state.requests[1].item ~= state.raw, "request has its own transport copy")

  local cached
  resolver.request(state.item, function(_, result)
    cached = result
  end)
  suite.assert_eq(1, #state.requests, "no second RPC for a successful result")
  suite.assert_eq("import alpha\n", cached.additionalTextEdits[1].newText, "cache retains side effects")
  suite.assert_true(state.timers[1].closed, "settled request closes its timer")
end)

suite:test("the last cancellation retires a request and ignores its late result", function()
  local state = fixture()
  local deliveries = 0
  local cancel = resolver.request(state.item, function()
    deliveries = deliveries + 1
  end)
  cancel()
  cancel()
  suite.assert_eq(1, #state.cancellations, "idempotent cancellation")
  suite.assert_true(state.timers[1].closed, "cancelled timer")
  state.requests[1].callback(nil, { detail = "late" })
  suite.assert_eq(0, deliveries, "late response ignored")
  resolver.request(state.item, function()
    deliveries = deliveries + 1
  end)
  suite.assert_eq(2, #state.requests, "cancelled result is not cached")
end)

suite:test("failure and timeout fall back without poisoning retries", function()
  local state = fixture()
  local errors = {}
  local results = {}
  ---@return fun(): nil
  local function request()
    return resolver.request(state.item, function(err, result)
      errors[#results + 1] = err
      results[#results + 1] = result
    end)
  end
  request()
  state.requests[1].callback({ code = -1, message = "retry" }, nil)
  suite.assert_eq(state.item, results[1], "error fallback")
  suite.assert_eq(-1, errors[1].code, "error forwarded")
  request()
  suite.assert_eq(2000, state.timers[2].timeout, "bounded resolve lifetime")
  state.timers[2].callback()
  suite.assert_eq(state.item, results[2], "timeout fallback")
  suite.assert_eq(2, state.cancellations[1], "timed out RPC cancelled")
  request()
  state.requests[2].callback(nil, { detail = "expired" })
  suite.assert_eq(2, #results, "expired response ignored")
  state.requests[3].callback(nil, { detail = "retried" })
  suite.assert_eq("retried", results[3].detail, "retry succeeds")
end)

suite:test("cached raw results normalize against each current view context", function()
  local state = fixture()
  resolver.request(state.item, function() end)
  state.requests[1].callback(nil, {
    additionalTextEdits = {
      { newText = "rest", range = { start = { line = 1, character = 3 }, ["end"] = { line = 1, character = 7 } } },
    },
  })
  local context = vim.tbl_extend(
    "force",
    {},
    state.context,
    { col = 3, line = "alp tail", keyword = "alp", end_col = 3 }
  )
  local item =
    protocol.normalize(state.raw, context, 0, 0, 0, nil, state.client, nil, nil, state.context, state.candidate)
  local cached
  resolver.request(item, function(_, result)
    cached = result
  end)
  suite.assert_eq(1, #state.requests, "candidate identity survives reranking")
  suite.assert_eq(3, cached.textEdit.range["end"].character, "current primary edit")
  suite.assert_eq(4, cached.additionalTextEdits[1].range.start.character, "retargeted additional edit")
  suite.assert_eq(8, cached.additionalTextEdits[1].range["end"].character, "retargeted additional edit end")
end)

suite:test("listener failure does not prevent other consumers receiving a result", function()
  local state = fixture()
  local deliveries = 0
  resolver.request(state.item, function()
    error("broken documentation callback")
  end)
  resolver.request(state.item, function()
    deliveries = deliveries + 1
  end)
  state.requests[1].callback(nil, { detail = "ready" })
  suite.assert_eq(1, deliveries, "healthy consumer")
  suite.assert_eq(1, #state.reports, "isolated callback diagnostic")
end)

suite:test("buffer disposal cancels pending work and releases successful cache entries", function()
  local state = fixture()
  local deliveries = 0
  resolver.request(state.item, function()
    deliveries = deliveries + 1
  end)
  resolver.clear(state.bufnr)
  state.requests[1].callback(nil, { detail = "late" })
  suite.assert_eq(0, deliveries, "disposed listener")
  suite.assert_eq(1, #state.cancellations, "disposed RPC")
  resolver.request(state.item, function() end)
  state.requests[2].callback(nil, { detail = "ready" })
  resolver.clear(state.bufnr)
  resolver.request(state.item, function() end)
  suite.assert_eq(3, #state.requests, "disposed cache is not reused")
end)

suite:test("invalid resolve payloads fail at ingress and remain retryable", function()
  local state = fixture()
  local result
  local failure
  resolver.request(state.item, function(err, value)
    failure = err
    result = value
  end)
  state.requests[1].callback(nil, { additionalTextEdits = false })
  suite.assert_true(failure ~= nil, "invalid payload error")
  suite.assert_eq(state.item, result, "original item fallback")
  resolver.request(state.item, function() end)
  suite.assert_eq(2, #state.requests, "invalid payload is not cached")
end)

suite:test("synchronous responses settle before request-id assignment and remain reusable", function()
  local state = fixture()
  local requests = 0
  state.client.request = function(_, _, _, callback)
    requests = requests + 1
    callback(nil, { detail = "synchronous" })
    return true, 99
  end
  local result
  local cancel = resolver.request(state.item, function(_, value)
    result = value
  end)
  cancel()
  resolver.request(state.item, function() end)
  suite.assert_eq("synchronous", result.detail, "synchronous delivery")
  suite.assert_eq(1, requests, "successful response reused")
  suite.assert_eq(0, #state.cancellations, "settled RPC is not cancelled")
  suite.assert_true(state.timers[1].closed, "synchronous timer cleanup")
end)

suite:test("client replacement retires old state before cancellation can invoke callbacks", function()
  local state = fixture()
  local stale_deliveries = 0
  resolver.request(state.item, function()
    stale_deliveries = stale_deliveries + 1
  end)
  state.client.cancel_request = function()
    state.requests[1].callback(nil, { detail = "cancel callback" })
  end
  state.client = vim.tbl_extend("force", {}, state.client)
  local resolved
  resolver.request(state.item, function(_, value)
    resolved = value
  end)
  suite.assert_eq(0, stale_deliveries, "old consumer is retired before external cancellation")
  suite.assert_eq(2, #state.requests, "replacement client gets its own request")
  state.requests[2].callback(nil, { detail = "replacement" })
  suite.assert_eq("replacement", resolved.detail, "new client result")
end)

suite:run()
