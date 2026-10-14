---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.keystroke.cmp.session" ---@type string

local harness = require("__test__.support.harness")
local runtime = require("__test__.fixtures.era.keystroke.cmp.runtime")
runtime.setup()
local t = harness.new("era.keystroke.cmp.session")
local Context = require("era.keystroke.cmp.context")
local Item = require("era.keystroke.cmp.item")
local Session = require("era.keystroke.cmp.session")

---@return nil
local function drain()
  local done = false
  -- The second barrier also waits for renders queued by source response callbacks.
  vim.schedule(function()
    vim.schedule(function()
      done = true
    end)
  end)
  t.wait_until(function()
    return done
  end, 1000, "scheduled responses and renders drained")
end

---@return table
local function fixture()
  local previous = vim.api.nvim_get_current_buf()
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  t:defer(function()
    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  local state = { context = runtime.context(""), created = 0, requests = {}, resolutions = {} }
  state.names = { "lsp" }
  t:patch_table(Context, "capture", function()
    return state.context
  end)
  t:patch_table(vim.lsp, "get_clients", function()
    return {}
  end)
  local new = yoz.completion.new_snapshot
  t:patch_table(yoz.completion, "new_snapshot", function(data)
    state.created = state.created + 1
    return new(data)
  end)
  local props = {
    sources = {
      lsp = {
        resolve = function(item, callback)
          local request = { item = item, callback = callback, cancelled = false }
          state.resolutions[#state.resolutions + 1] = request
          return function()
            request.cancelled = true
          end
        end,
        complete = function(context, callback)
          local request = { context = context, callback = callback, cancelled = false }
          state.requests[#state.requests + 1] = request
          if state.response ~= nil then
            callback(state.response)
          end
          return function()
            request.cancelled = true
          end
        end,
      },
    },
    sources_for = function()
      return state.names
    end,
  }
  local session = Session.new(props)
  -- These cases exercise source ownership and caching; native rendering is covered by RPC input/UI specs.
  t:patch_table(session.menu, "show", function(menu, _, items)
    menu.active = #items > 0
  end)
  t:patch_table(session.menu, "is_visible", function(menu)
    return menu.active
  end)
  t:patch_table(session.menu, "hide", function(menu)
    menu.active = false
  end)
  t:patch_table(session.menu, "geometry", function()
    return nil
  end)
  state.sources = props.sources
  state.session = session
  t:defer(function()
    session:destroy()
    drain()
  end)

  ---@param query                       string
  ---@param version                     ?integer
  ---@return nil
  function state:update(query, version)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { query })
    self.context = runtime.context(query)
    self.context.buffer_version = version or 0
    session:before_input()
    session:update(self.context)
  end
  return state
end

---@param context                       era.keystroke.cmp.IContext
---@param labels                        string[]
---@param incomplete                    ?boolean
---@return era.keystroke.cmp.IResponse
local function response(context, labels, incomplete)
  local items = {}
  for _, label in ipairs(labels) do
    items[#items + 1] = assert(Item.new(context, "lsp", { label = label, kind = 6 }))
  end
  return { items = items, incomplete = incomplete == true }
end

t:test("rapid append and backspace retain the settled snapshot across superseded callbacks", function()
  local state = fixture()
  state.response = response(runtime.context("g"), { "getOne", "getOther", "getUser" })
  state:update("g")
  drain()
  t.assert_eq(1, state.created, "initial snapshot")
  for _, query in ipairs({ "ge", "get", "getO", "get", "ge", "g" }) do
    state:update(query)
  end
  drain()
  t.assert_eq(1, state.created, "unchanged candidate set is not rebuilt")
  t.assert_eq(3, #state.session.items, "widened query returns every candidate")
  t.assert_eq("g", state.session.context.line, "last input wins")
end)

t:test("backspace keeps provisional candidates while the broader query is pending", function()
  local state = fixture()
  state.response = response(runtime.context("alp"), { "alpha", "alpine" }, true)
  state:update("alp")
  drain()
  state.response = nil
  state:update("al")
  drain()
  t.assert_eq(2, #state.session.items, "compatible candidates remain visible while the wider query refreshes")
  t.assert_eq(1, state.created, "provisional display reuses the existing snapshot")
  local latest = state.requests[#state.requests]
  latest.callback(response(latest.context, {}))
  drain()
  t.assert_eq(0, #state.session.items, "a settled empty response replaces the provisional list")
end)

t:test("new response arrays with the same items reuse the prepared candidate set", function()
  local state = fixture()
  local original = response(runtime.context("g"), { "getOne", "getOther" })
  state.response = original
  state:update("g")
  drain()
  for _, query in ipairs({ "ge", "get", "ge", "g" }) do
    state.response = { items = vim.list_extend({}, original.items), incomplete = false }
    state:update(query)
  end
  drain()
  t.assert_eq(1, state.created, "new aggregate arrays do not rebuild identical items")
  t.assert_eq(2, #state.session.items, "candidate identity and membership preserved")
end)

t:test("new candidates replace the snapshot and a cancelled response cannot overwrite it", function()
  local state = fixture()
  state.response = response(runtime.context("g"), { "getOld" }, true)
  state:update("g")
  drain()
  state.response = nil
  state:update("ge")
  local obsolete = state.requests[#state.requests]
  state:update("get")
  local current = state.requests[#state.requests]
  local fresh = response(current.context, { "getFresh" }, true)
  current.callback(fresh)
  obsolete.callback(response(obsolete.context, { "getStale" }, true))
  drain()
  t.assert_true(obsolete.cancelled, "obsolete request cancelled")
  t.assert_eq(2, state.created, "only the fresh candidate set is prepared")
  t.assert_eq("getFresh", state.session.items[1].raw.label, "late response ignored")
  state.response = fresh
  state:update("getF")
  state:update("get")
  drain()
  t.assert_eq(2, state.created, "replacement snapshot survives further queued updates")
  t.assert_eq("getFresh", state.session.items[1].raw.label, "new snapshot remains current")
end)

t:test("hiding releases the prepared snapshot and queued callbacks cannot reopen it", function()
  local state = fixture()
  state.response = response(runtime.context("g"), { "getOne" })
  state:update("g")
  drain()
  state:update("ge")
  state.session:hide()
  drain()
  t.assert_eq(1, state.created, "dismissed callback does no candidate work")
  t.assert_eq(0, #state.session.items, "dismissed candidates stay absent")
  t.assert_false(state.session:is_visible(), "dismissed menu stays closed")
  state:update("ge")
  drain()
  t.assert_eq(2, state.created, "new session prepares its own snapshot")
end)

t:test("an external buffer revision rejects old presentation and late responses", function()
  local state = fixture()
  state.response = response(runtime.context("g"), { "getOld" }, true)
  state:update("g")
  drain()
  state.response = nil
  state:update("ge")
  local obsolete = state.requests[#state.requests]
  state:update("ge", 1)
  local current = state.requests[#state.requests]
  t.assert_eq(0, #state.session.items, "incompatible snapshot is not shown")
  obsolete.callback(response(obsolete.context, { "getStale" }))
  current.callback(response(current.context, { "getCurrent" }))
  drain()
  t.assert_eq(2, state.created, "only the current owner prepares candidates")
  t.assert_eq("getCurrent", state.session.items[1].raw.label, "current buffer revision owns the menu")
end)

t:test("buffer fallback waits for empty primary responses and cannot republish after suppression", function()
  local state = fixture()
  state.names = { "lsp", "path", "buffer" }
  local path_callback, buffer_callback
  local buffer_requests, buffer_cancelled = 0, false
  state.sources.path = {
    complete = function(_, callback)
      path_callback = callback
    end,
  }
  state.sources.buffer = {
    complete = function(_, callback)
      buffer_requests = buffer_requests + 1
      buffer_callback = callback
      return function()
        buffer_cancelled = true
      end
    end,
  }
  state:update("a")
  drain()
  t.assert_eq(0, buffer_requests, "pending primary sources do not start buffer scanning")
  local lsp = state.requests[1]
  lsp.callback({ items = {}, incomplete = true, pending = true })
  path_callback({ items = {}, incomplete = false })
  drain()
  t.assert_eq(0, buffer_requests, "another LSP client is still pending")
  lsp.callback({ items = {}, incomplete = true, pending = false })
  drain()
  t.assert_eq(1, buffer_requests, "empty settled response permits fallback even when isIncomplete is true")
  buffer_callback({ items = { assert(Item.new(state.context, "buffer", { label = "albatross" })) }, incomplete = false })
  drain()
  t.assert_eq("albatross", state.session.items[1].raw.label, "fallback candidate is visible")
  lsp.callback(response(lsp.context, { "alpha" }))
  buffer_callback({ items = { assert(Item.new(state.context, "buffer", { label = "ancient" })) }, incomplete = false })
  drain()
  t.assert_true(buffer_cancelled, "new primary items cancel the fallback owner")
  t.assert_eq(1, #state.session.items, "late fallback response stays suppressed")
  t.assert_eq("alpha", state.session.items[1].raw.label, "primary item owns the menu")
end)

t:test("workspace paths do not delay buffer fallback while scanning", function()
  local state = fixture()
  state.names = { "lsp", "path_at", "buffer" }
  state.response = { items = {}, incomplete = false }
  local path_callback
  local buffer_requests = 0
  state.sources.path_at = {
    complete = function(_, callback)
      path_callback = callback
    end,
  }
  state.sources.buffer = {
    complete = function(context, callback)
      buffer_requests = buffer_requests + 1
      callback({ items = { assert(Item.new(context, "buffer", { label = "albatross" })) }, incomplete = false })
    end,
  }
  state:update("@a")
  drain()
  t.assert_eq(1, buffer_requests, "path_at is independent even before its response")
  path_callback({ items = { assert(Item.new(state.context, "path_at", { label = "assets" })) }, incomplete = false })
  drain()
  t.assert_eq(1, buffer_requests, "path_at response does not restart buffer fallback")
  t.assert_eq(2, #state.session.items, "workspace paths and fallback words remain available")
end)

t:test("source policy distinguishes workspace paths before starting requests", function()
  local Policy = require("era.keystroke.cmp.policy")
  local workspace = Policy.sources_for(runtime.context("@a"), false)
  local ordinary = Policy.sources_for(runtime.context("./a"), false)
  t.assert_true(vim.list_contains(workspace, "path_at"), "workspace path owner")
  t.assert_false(vim.list_contains(workspace, "path"), "one path source is requested")
  t.assert_true(vim.list_contains(ordinary, "path"), "ordinary paths retain buffer dependency")
  t.assert_false(vim.list_contains(ordinary, "path_at"), "policy does not mutate shared source lists")
end)

t:test("eligible buffer fallback keeps its completed snapshot across prefix changes", function()
  local state = fixture()
  state.names = { "lsp", "buffer" }
  state.response = { items = {}, incomplete = false }
  local buffer_requests = 0
  state.sources.buffer = {
    complete = function(context, callback)
      buffer_requests = buffer_requests + 1
      callback({ items = { assert(Item.new(context, "buffer", { label = "alpha" })) }, incomplete = false })
    end,
  }
  state:update("a")
  drain()
  state:update("al")
  drain()
  t.assert_eq(1, buffer_requests, "compatible completed buffer response is reused")
  t.assert_eq("alpha", state.session.items[1].raw.label, "reused fallback stays visible")
end)

t:test("manual refresh discovers new directory entries without hiding the menu", function()
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  t:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  vim.fn.writefile({}, directory .. "/alpha_one.lua")
  local state = fixture()
  state.names = { "path" }
  local Path = require("era.keystroke.cmp.source.path")
  local requests = 0
  state.sources.path = {
    complete = function(context, callback)
      requests = requests + 1
      return Path.complete(context, callback)
    end,
  }
  state:update('"' .. directory .. "/al")
  t.wait_until(function()
    return #state.session.items == 1
  end, 1000, "initial directory response")
  t.assert_eq("alpha_one.lua", state.session.items[1].raw.label)
  vim.fn.writefile({}, directory .. "/alpha_two.lua")
  state.session:update(state.context, true)
  t.wait_until(function()
    return #state.session.items == 2
  end, 1000, "manual refresh sees the new file")
  t.assert_eq(2, requests, "same query starts a fresh directory scan")
  t.assert_true(state.session:is_visible(), "fresh candidates remain presented")
end)

t:test("manual buffer refresh includes background edits at the same input prefix", function()
  local state = fixture()
  local background = vim.api.nvim_create_buf(true, false)
  t:defer(function()
    vim.api.nvim_buf_delete(background, { force = true })
  end)
  vim.api.nvim_buf_set_lines(background, 0, -1, false, { "", "alpha_one", "" })
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = { { bufnr = background } } }
  end)
  state.names = { "buffer" }
  state.sources.buffer = require("era.keystroke.cmp.source.buffer")
  state:update("a")
  drain()
  t.assert_eq("alpha_one", state.session.items[1].raw.label)
  vim.api.nvim_buf_set_lines(background, 1, 2, false, { "alpha_two" })
  state:update("al")
  drain()
  t.assert_eq("alpha_one", state.session.items[1].raw.label, "automatic prefix growth keeps the settled response")
  state.session:update(state.context, true)
  drain()
  t.assert_eq(1, #state.session.items)
  t.assert_eq("alpha_two", state.session.items[1].raw.label, "manual query applies pending source edits")
end)

t:test("manual flag forces LSP refresh without mutating the caller's context", function()
  local state = fixture()
  local requests = {}
  local label = "alpha_one"
  local client = {
    id = 8401,
    name = "manual-refresh",
    offset_encoding = "utf-16",
    server_capabilities = { completionProvider = {} },
    request = function(_, method, params, callback)
      t.assert_eq("textDocument/completion", method)
      requests[#requests + 1] = params
      callback(nil, { { label = label } })
      return true, #requests
    end,
    cancel_request = function() end,
  }
  t:patch_table(vim.lsp, "get_clients", function(options)
    return options.method == "textDocument/completion" and { client } or {}
  end)
  state.sources.lsp = require("era.keystroke.cmp.source.lsp")
  state:update("a")
  drain()
  label = "alpha_two"
  state:update("al")
  drain()
  t.assert_eq(1, #requests, "complete LSP list is reused automatically")
  t.assert_eq("alpha_one", state.session.items[1].raw.label)
  state.session:update(state.context, true)
  drain()
  t.assert_eq(2, #requests, "manual flag bypasses the client response cache")
  t.assert_eq(1, requests[2].context.triggerKind, "Invoked")
  t.assert_nil(requests[2].context.triggerCharacter)
  t.assert_eq("alpha_two", state.session.items[1].raw.label)
  t.assert_eq("typing", state.context.trigger, "caller retains its original snapshot")
end)

t:run()
