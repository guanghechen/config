local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local Diagnostic = require("era.m.lsp.diagnostic")

local ROOT = vim.uv.cwd() .. "/__test__/local.diagnostic" ---@type string
local ERROR, WARN = vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN

---@return era.m.lsp.diagnostic.Store
---@return { changes: integer }
local function new_store()
  local state = { changes = 0 }
  local store = Diagnostic.Store.new({
    debounce_ms = 10,
    on_change = function()
      state.changes = state.changes + 1
    end,
  })
  t:defer(function()
    store:dispose()
  end)
  return store, state
end

---@param name                          string
---@return integer
local function named_buffer(name)
  local bufnr = vim.api.nvim_create_buf(true, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_name(bufnr, ROOT .. "/" .. name)
  return bufnr
end

---@param name                          string
---@return integer
local function namespace(name)
  local ns = vim.api.nvim_create_namespace("diagnostic-spec-" .. name)
  t:defer(function()
    vim.diagnostic.reset(ns)
  end)
  return ns
end

---@param ns                            integer
---@param bufnr                         integer
---@param severities                    vim.diagnostic.Severity[]
---@return nil
local function set(ns, bufnr, severities)
  local diagnostics = {} ---@type vim.Diagnostic.Set[]
  for index, severity in ipairs(severities) do
    diagnostics[index] = { lnum = 0, col = 0, message = "diagnostic " .. index, severity = severity }
  end
  vim.diagnostic.set(ns, bufnr, diagnostics)
end

-- Counts buffer-scoped queries, which tell a test that a batched refresh has run.
---@return table<integer, integer>
local function count_queries()
  local calls = {} ---@type table<integer, integer>
  local get = vim.diagnostic.get
  t:patch_table(vim.diagnostic, "get", function(bufnr, opts)
    if bufnr ~= nil then
      calls[bufnr] = (calls[bufnr] or 0) + 1
    end
    return get(bufnr, opts)
  end)
  return calls
end

---@param predicate                     fun(): boolean
---@param message                       string
---@return nil
local function wait(predicate, message)
  t.assert_true(vim.wait(2000, predicate, 1), message)
end

t:test("refresh: unchanged counts do not report a change", function()
  local store, state = new_store()
  local bufnr = named_buffer("unchanged.lua")
  local ns = namespace("unchanged")
  local calls = count_queries()

  ---@param changes                     integer
  ---@param message                     string
  local function refresh(changes, message)
    local before = calls[bufnr] or 0 ---@type integer
    store:refresh(bufnr)
    wait(function()
      return (calls[bufnr] or 0) > before
    end, "refresh ran: " .. message)
    t.assert_eq(changes, state.changes, message)
  end

  set(ns, bufnr, { ERROR })
  refresh(1, "initial diagnostic")
  refresh(1, "unchanged diagnostic")
  set(ns, bufnr, { WARN })
  refresh(2, "changed severity")
  set(ns, bufnr, {})
  refresh(3, "cleared diagnostic")
end)

t:test("refresh: debounce retains every changed buffer", function()
  local store, state = new_store()
  local bufnr1 = named_buffer("pending-1.lua")
  local bufnr2 = named_buffer("pending-2.lua")
  local ns = namespace("pending")
  set(ns, bufnr1, { ERROR })
  set(ns, bufnr2, { WARN, WARN })
  local calls = count_queries()

  store:refresh(bufnr1)
  store:refresh(bufnr1)
  store:refresh(bufnr2)
  t.assert_nil(calls[bufnr1], "queries before debounce flush")
  t.assert_nil(calls[bufnr2], "queries before debounce flush")

  wait(function()
    return state.changes > 0
  end, "debounced refresh")
  t.assert_eq(1, calls[bufnr1], "deduplicated first buffer")
  t.assert_eq(1, calls[bufnr2], "retained second buffer")
  t.assert_eq(1, state.changes, "batched change")
  t.assert_eq(1, store:get(bufnr1).error, "first buffer errors")
  t.assert_eq(2, store:get(bufnr2).warn, "second buffer warnings")
end)

t:test("refresh: aggregates every diagnostic namespace in the buffer", function()
  local store, state = new_store()
  local bufnr = named_buffer("namespaces.lua")
  local ns1 = namespace("namespace-1")
  local ns2 = namespace("namespace-2")

  set(ns1, bufnr, { ERROR })
  set(ns2, bufnr, { WARN })
  store:refresh(bufnr)
  wait(function()
    return state.changes == 1
  end, "initial namespaces")
  local data = store:get(bufnr)
  t.assert_eq(1, data.error, "namespace error")
  t.assert_eq(1, data.warn, "namespace warning")

  vim.diagnostic.reset(ns1, bufnr)
  store:refresh(bufnr)
  wait(function()
    return state.changes == 2
  end, "cleared namespace")
  data = store:get(bufnr)
  t.assert_eq(0, data.error, "cleared namespace error")
  t.assert_eq(1, data.warn, "remaining namespace warning")
end)

t:test("forget: a deleted buffer drops its counts and queued refresh", function()
  local store, state = new_store()
  local bufnr = named_buffer("deleted.lua")
  local other = named_buffer("other.lua")
  local ns = namespace("deleted")
  set(ns, bufnr, { ERROR })
  store:refresh_all()
  t.assert_eq(1, state.changes, "initial diagnostic")
  t.assert_eq(1, store:get(bufnr).error, "initial count")

  store:refresh(bufnr)
  store:forget(bufnr)
  store:forget(bufnr)
  t.assert_eq(2, state.changes, "deleted diagnostic")
  t.assert_eq(0, store:get(bufnr).error, "deleted count")

  -- Queued refreshes run as one batch: once a later one lands, a refresh still queued for the deleted buffer would too.
  set(ns, other, { WARN })
  store:refresh(other)
  wait(function()
    return state.changes == 3
  end, "later refresh")
  t.assert_eq(1, store:get(other).warn, "later count")
  t.assert_eq(0, store:get(bufnr).error, "dropped queued refresh")
end)

t:test("setup: diagnostic changes and deleted buffers reach the default store", function()
  local bufnr = named_buffer("setup.lua")
  local ns = namespace("setup")
  set(ns, bufnr, { ERROR })
  Diagnostic.setup()
  t:defer(function()
    -- Creating the group again clears the autocmds setup registered.
    stl.nvim.fn.augroup("era.m.lsp.diagnostic")
  end)
  t.assert_eq(1, Diagnostic.get_by_bufnr(bufnr).error, "initial count")

  set(ns, bufnr, { WARN, WARN })
  wait(function()
    return Diagnostic.get_by_bufnr(bufnr).warn == 2
  end, "DiagnosticChanged refresh")
  t.assert_eq(0, Diagnostic.get_by_bufnr(bufnr).error, "replaced count")
  t.assert_eq(
    Diagnostic.format(Diagnostic.get_by_bufnr(bufnr), 0, {}),
    Diagnostic.render(ROOT .. "/setup.lua", 0, {}),
    "render"
  )

  vim.api.nvim_buf_delete(bufnr, { force = true })
  t.assert_eq(0, Diagnostic.get_by_bufnr(bufnr).warn, "deleted buffer")
end)

t:run()
