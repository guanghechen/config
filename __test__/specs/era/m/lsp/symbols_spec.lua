--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/lsp/symbols_spec.lua
---@diagnostic disable: undefined-global, invisible

local harness = require("__test__.support.harness")

local t = harness.new("era.m.lsp.symbols")

---@class era.m.lsp.symbols.test.ICall
---@field handler                       fun(err: any, result: any, ctx: table): nil
---@field ids                           table<integer, integer>

---@class era.m.lsp.symbols.test.ITimer
---@field fn                            fun(): nil
---@field ms                            integer
---@field cleared                       boolean

---@class era.m.lsp.symbols.test.IFixture
---@field Symbols                       era.m.lsp.symbols
---@field bufnr                         integer
---@field winnr                         integer
---@field now                           integer
---@field clients                       { id: integer }[]
---@field calls                         era.m.lsp.symbols.test.ICall[]
---@field cancels                       integer
---@field timers                        era.m.lsp.symbols.test.ITimer[]
---@field scheduled                     fun()[]
---@field errors                        table[]
---@field suppress                      boolean
---@field ready                         table<integer, boolean>
---@field pum                           boolean
---@field on_issue                      ?fun(call: era.m.lsp.symbols.test.ICall): nil

---@param lines                         ?string[]
---@return era.m.lsp.symbols.test.IFixture
local function setup(lines)
  local fixture = {
    now = 1000,
    clients = { { id = 1 } },
    calls = {},
    cancels = 0,
    timers = {},
    scheduled = {},
    errors = {},
    suppress = false,
    ready = {},
    pum = false,
  } ---@type era.m.lsp.symbols.test.IFixture

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or { "function outer()", "  local inner = 1", "end" })
  vim.api.nvim_buf_set_name(bufnr, "/tmp/symbols-spec-" .. bufnr .. ".lua")
  vim.b[bufnr].support_documentSymbol = 1
  local previous_bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_buf(bufnr)
  t:defer(function()
    vim.cmd("silent! only")
    if vim.api.nvim_buf_is_valid(previous_bufnr) then
      vim.api.nvim_set_current_buf(previous_bufnr)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  fixture.bufnr = bufnr
  fixture.winnr = vim.api.nvim_get_current_win()

  t:patch_global("stl", {
    fn = { noop = function() end },
    nvim = {
      fn = {
        augroup = function(name)
          return vim.api.nvim_create_augroup("spec_" .. name, { clear = true })
        end,
      },
    },
    reporter = {
      error = function(report)
        fixture.errors[#fixture.errors + 1] = report
      end,
    },
    timer = {
      delay = function(fn, ms)
        local timer = { fn = fn, ms = ms, cleared = false } ---@type era.m.lsp.symbols.test.ITimer
        fixture.timers[#fixture.timers + 1] = timer
        return timer
      end,
      clear_timer = function(timer)
        if timer ~= nil then
          timer.cleared = true
        end
      end,
    },
  })
  t:patch_global("dot", {
    var = { N_WINLINE_DISABLED = "dot_winline_disabled" },
    state = {
      status = {
        lsp_symbol_ready = fixture.ready,
        suppress_warning = {
          snapshot = function()
            return fixture.suppress
          end,
        },
      },
    },
  })
  t:patch_table(vim.uv, "now", function()
    return fixture.now
  end)
  t:patch_table(vim, "schedule", function(callback)
    fixture.scheduled[#fixture.scheduled + 1] = callback
  end)
  t:patch_table(vim.fn, "pumvisible", function()
    return fixture.pum and 1 or 0
  end)
  t:patch_table(vim.lsp, "get_clients", function()
    return fixture.clients
  end)
  t:patch_table(vim.lsp, "get_client_by_id", function(client_id)
    return {
      id = client_id,
      offset_encoding = "utf-16",
      requests = setmetatable({}, {
        __index = function()
          return { type = "pending" }
        end,
      }),
      cancel_request = function()
        fixture.cancels = fixture.cancels + 1
      end,
    }
  end)
  t:patch_table(vim.lsp, "buf_request", function(_, method, _, handler)
    t.assert_eq("textDocument/documentSymbol", method, "request method")
    local ids = {} ---@type table<integer, integer>
    for _, client in ipairs(fixture.clients) do
      ids[client.id] = #fixture.calls + 1
    end
    local call = { handler = handler, ids = ids } ---@type era.m.lsp.symbols.test.ICall
    fixture.calls[#fixture.calls + 1] = call
    if fixture.on_issue ~= nil then
      fixture.on_issue(call)
    end
    return ids, function()
      fixture.cancels = fixture.cancels + 1
    end
  end)

  fixture.Symbols = assert(loadfile("lua/era/m/lsp/symbols.lua"))()
  t:defer(function()
    pcall(vim.api.nvim_del_augroup_by_name, "spec_era.m.lsp.symbols")
  end)
  return fixture
end

---@param fixture                       era.m.lsp.symbols.test.IFixture
---@return nil
local function drain(fixture)
  while #fixture.scheduled > 0 do
    table.remove(fixture.scheduled, 1)()
  end
end

---@param fixture                       era.m.lsp.symbols.test.IFixture
---@param ms                            integer
---@return nil
local function advance(fixture, ms)
  fixture.now = fixture.now + ms
  for _, timer in ipairs(vim.list_extend({}, fixture.timers)) do
    if not timer.cleared then
      timer.cleared = true
      timer.fn()
    end
  end
  drain(fixture)
end

---@param name                          string
---@param inner                         ?table
---@return table[]
local function document(name, inner)
  return {
    {
      name = name,
      kind = 12,
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 2, character = 3 } },
      children = inner and { inner } or vim.NIL,
    },
  }
end

---@param call                          era.m.lsp.symbols.test.ICall
---@param result                        any
---@param err                           ?table
---@param client_id                     ?integer
---@return nil
local function respond(call, result, err, client_id)
  call.handler(err, result, { client_id = client_id or 1 })
end

---@param symbols                       dot.t.ILspSymbol[]|nil
---@return string|nil
local function names(symbols)
  if symbols == nil then
    return nil
  end
  local out = {} ---@type string[]
  for _, symbol in ipairs(symbols) do
    out[#out + 1] = string.format("%s:%s@%d:%d", symbol.kind, symbol.name, symbol.row, symbol.col)
  end
  return table.concat(out, ">")
end

---@param fixture                       era.m.lsp.symbols.test.IFixture
---@return table<integer, string>
local function request(fixture, ...)
  local delivered = {} ---@type table<integer, string>
  for _, winnr in ipairs({ ... }) do
    fixture.Symbols.request(winnr, function(target, symbols)
      delivered[target] = assert(names(symbols))
    end)
  end
  return delivered
end

t:test("windows in one batch share one request and each gets the path at its cursor", function()
  local fixture = setup()
  vim.cmd("vsplit")
  local other = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(other, { 2, 4 })

  local delivered = request(fixture, fixture.winnr, other)
  drain(fixture)
  t.assert_eq(1, #fixture.calls, "requests")
  respond(
    fixture.calls[1],
    document("outer", {
      name = "inner",
      kind = 13,
      range = { start = { line = 1, character = 2 }, ["end"] = { line = 1, character = 17 } },
    })
  )

  t.assert_eq("Function:outer@1:1", delivered[fixture.winnr], "first window")
  t.assert_eq("Function:outer@1:1>Variable:inner@2:3", delivered[other], "second window")
  t.assert_true(fixture.ready[1], "responding client is ready")
end)

t:test("a trigger during an in-flight request waits for a trailing request", function()
  local fixture = setup()
  request(fixture, fixture.winnr)
  drain(fixture)
  local delivered = request(fixture, fixture.winnr)
  drain(fixture)
  t.assert_eq(1, #fixture.calls, "requests while in flight")

  respond(fixture.calls[1], document("old"))
  drain(fixture)
  t.assert_eq(1, #fixture.calls, "requests within the interval")
  advance(fixture, 128)
  t.assert_eq(2, #fixture.calls, "trailing request")
  respond(fixture.calls[2], document("new"))
  t.assert_eq("Function:new@1:1", delivered[fixture.winnr], "trailing result")
end)

t:test("every trigger is answered by a later request even when the snapshot holds", function()
  local fixture = setup()
  request(fixture, fixture.winnr)
  drain(fixture)
  respond(fixture.calls[1], document("inactive"))
  fixture.now = fixture.now + 1000

  local delivered = request(fixture, fixture.winnr)
  t.assert_eq("Function:inactive@1:1", names(fixture.Symbols.path(fixture.winnr)), "confirmed path")
  drain(fixture)
  t.assert_eq(2, #fixture.calls, "fresh request")
  respond(fixture.calls[2], document("active"))
  t.assert_eq("Function:active@1:1", delivered[fixture.winnr], "server change")
  t.assert_eq("Function:active@1:1", names(fixture.Symbols.path(fixture.winnr)), "reconfirmed path")
end)

t:test("the confirmed tree only serves its own snapshot", function()
  local fixture = setup()
  request(fixture, fixture.winnr)
  drain(fixture)
  respond(fixture.calls[1], document("outer"))
  t.assert_true(fixture.Symbols.path(fixture.winnr) ~= nil, "same snapshot")

  vim.api.nvim_buf_set_name(fixture.bufnr, "/tmp/symbols-spec-renamed.lua")
  t.assert_nil(fixture.Symbols.path(fixture.winnr), "renamed document")
  vim.api.nvim_buf_set_name(fixture.bufnr, "/tmp/symbols-spec-" .. fixture.bufnr .. ".lua")
  t.assert_true(fixture.Symbols.path(fixture.winnr) ~= nil, "original document")

  fixture.clients = { { id = 2 } }
  t.assert_nil(fixture.Symbols.path(fixture.winnr), "restarted client")
  fixture.clients = { { id = 1 } }
  vim.api.nvim_buf_set_lines(fixture.bufnr, -1, -1, false, { "" })
  t.assert_nil(fixture.Symbols.path(fixture.winnr), "edited text")
end)

t:test("a response for edited text is delivered without being confirmed", function()
  local fixture = setup()
  local delivered = request(fixture, fixture.winnr)
  drain(fixture)
  vim.api.nvim_buf_set_lines(fixture.bufnr, -1, -1, false, { "" })
  respond(fixture.calls[1], document("outer"))

  t.assert_eq("Function:outer@1:1", delivered[fixture.winnr], "delivered")
  t.assert_nil(fixture.Symbols.path(fixture.winnr), "confirmed path")
end)

t:test("failures keep the shown path, unconfirm the tree and follow the error policy", function()
  local fixture = setup()
  request(fixture, fixture.winnr)
  drain(fixture)
  respond(fixture.calls[1], document("outer"))

  fixture.now = fixture.now + 1000
  local delivered = request(fixture, fixture.winnr)
  drain(fixture)
  respond(fixture.calls[2], nil, { message = "Content modified." })
  t.assert_nil(delivered[fixture.winnr], "nothing delivered")
  t.assert_nil(fixture.Symbols.path(fixture.winnr), "unconfirmed")
  t.assert_eq(0, #fixture.errors, "content modified is silent")

  fixture.now = fixture.now + 1000
  request(fixture, fixture.winnr)
  drain(fixture)
  respond(fixture.calls[3], nil, { message = "boom" })
  t.assert_eq(1, #fixture.errors, "reported failure")

  fixture.suppress = true
  fixture.now = fixture.now + 1000
  request(fixture, fixture.winnr)
  drain(fixture)
  respond(fixture.calls[4], nil, { message = "boom" })
  t.assert_eq(1, #fixture.errors, "suppressed failure")

  fixture.now = fixture.now + 1000
  request(fixture, fixture.winnr)
  drain(fixture)
  respond(fixture.calls[5], nil, { message = "trying to get AST for non-added document" })
  t.assert_true(vim.b[fixture.bufnr].dot_winline_disabled, "disabled document")
  request(fixture, fixture.winnr)
  drain(fixture)
  t.assert_eq(5, #fixture.calls, "gated after disabling")
end)

t:test("unsupported buffers and the current window with a popup menu are skipped", function()
  local fixture = setup()
  vim.b[fixture.bufnr].support_documentSymbol = 0
  request(fixture, fixture.winnr)
  drain(fixture)
  t.assert_eq(0, #fixture.calls, "unsupported")

  vim.b[fixture.bufnr].support_documentSymbol = 1
  fixture.pum = true
  request(fixture, fixture.winnr)
  drain(fixture)
  t.assert_eq(0, #fixture.calls, "popup menu")
end)

t:test("a timeout reports only after every client answered once", function()
  local fixture = setup()
  request(fixture, fixture.winnr)
  drain(fixture)
  advance(fixture, 10000)
  t.assert_eq(0, #fixture.errors, "client still starting")
  t.assert_eq(1, fixture.cancels, "cancelled")

  fixture.ready[1] = true
  request(fixture, fixture.winnr)
  drain(fixture)
  advance(fixture, 10000)
  t.assert_eq(1, #fixture.errors, "timed out")
end)

t:test("the last outstanding client detaching settles the request", function()
  local fixture = setup()
  request(fixture, fixture.winnr)
  drain(fixture)
  vim.api.nvim_exec_autocmds("LspDetach", { buffer = fixture.bufnr, data = { client_id = 1 }, modeline = false })
  t.assert_eq(1, fixture.cancels, "detached client request cancelled")

  fixture.now = fixture.now + 1000
  request(fixture, fixture.winnr)
  drain(fixture)
  t.assert_eq(2, #fixture.calls, "next request after detach")
  t.assert_eq(0, #fixture.errors, "silent detach")
end)

t:test("the first client answer wins, errors included", function()
  local fixture = setup()
  fixture.clients = { { id = 1 }, { id = 2 } }
  local delivered = request(fixture, fixture.winnr)
  drain(fixture)
  respond(fixture.calls[1], nil, { message = "Content modified." }, 2)
  respond(fixture.calls[1], document("late"), nil, 1)
  t.assert_nil(delivered[fixture.winnr], "late success ignored")
  t.assert_true(fixture.ready[1] and fixture.ready[2], "both clients ready")
end)

t:test("an in-process server may answer before the request returns", function()
  local fixture = setup()
  fixture.on_issue = function(call)
    respond(call, document("sync"))
  end
  local delivered = request(fixture, fixture.winnr)
  drain(fixture)
  t.assert_eq("Function:sync@1:1", delivered[fixture.winnr], "synchronous answer")
  t.assert_eq(0, #fixture.timers, "no timeout armed")
end)

t:test("large documents space requests but always send the trailing request", function()
  local fixture = setup()
  local large = {} ---@type table[]
  for index = 0, 10000 do
    large[#large + 1] = {
      name = "symbol" .. index,
      kind = 12,
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 1 } },
    }
  end
  request(fixture, fixture.winnr)
  drain(fixture)
  respond(fixture.calls[1], large)

  fixture.now = fixture.now + 1000
  request(fixture, fixture.winnr)
  drain(fixture)
  t.assert_eq(1, #fixture.calls, "request within the large interval")
  t.assert_true(fixture.Symbols.path(fixture.winnr) ~= nil, "confirmed path meanwhile")
  advance(fixture, 4000)
  t.assert_eq(2, #fixture.calls, "trailing request")

  vim.api.nvim_buf_set_lines(fixture.bufnr, -1, -1, false, { "" })
  respond(fixture.calls[2], large)
  fixture.now = fixture.now + 200
  request(fixture, fixture.winnr)
  drain(fixture)
  t.assert_eq(3, #fixture.calls, "edited text uses the normal interval")
end)

t:test("wiping the buffer drops its state and ignores late answers", function()
  local fixture = setup()
  local delivered = request(fixture, fixture.winnr)
  drain(fixture)
  local call = fixture.calls[1]
  local bufnr = fixture.bufnr
  vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
  vim.api.nvim_buf_delete(bufnr, { force = true })

  t.assert_eq(1, fixture.cancels, "cancelled")
  respond(call, document("late"))
  t.assert_nil(next(delivered), "nothing delivered")
end)

t:run()
