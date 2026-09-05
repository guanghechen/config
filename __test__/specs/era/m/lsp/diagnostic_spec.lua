--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/lsp/diagnostic_spec.lua
---@diagnostic disable: undefined-global, invisible
--- Test for era.m.lsp.diagnostic module

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.lsp.diagnostic")
local run_refresh_pending ---@type fun()|nil

bootstrap.with_runtime(t, {
  dot = {
    state = {
      status = {
        dirtier_statusline = { mark_dirty = function() end },
        dirtier_tabline = { mark_dirty = function() end },
      },
    },
  },
  stl = {
    c = {
      Subscribers = {
        new = function()
          return {
            notify = function() end,
            subscribe = function()
              return { unsubscribe = function() end }
            end,
            dispose = function() end,
          }
        end,
      },
    },
    nvim = {
      fn = {
        augroup = function()
          return 1
        end,
      },
    },
    timer = {
      debounce = function(callback)
        run_refresh_pending = callback
        return function() end
      end,
    },
  },
})

local Diagnostic = require("era.m.lsp.diagnostic")

---@return { notifications: integer }
local function reset_state()
  local state = { notifications = 0 }
  t:patch_table(Diagnostic, "_buffers", {})
  t:patch_table(Diagnostic, "_subscribers_bufnr", {})
  t:patch_table(Diagnostic, "_subscribers_all", {
    notify = function()
      state.notifications = state.notifications + 1
    end,
  })
  t:patch_table(Diagnostic, "_total_error", 0)
  t:patch_table(Diagnostic, "_total_warn", 0)
  t:patch_table(Diagnostic, "_total_info", 0)
  t:patch_table(Diagnostic, "_total_hint", 0)
  return state
end

local function flush_refresh()
  assert(run_refresh_pending ~= nil, "missing refresh callback")
  run_refresh_pending()
end

t:test("refresh: unchanged counts do not notify subscribers", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_name(bufnr, "diagnostic-false-notification-test.lua")

  local diagnostics = {
    { bufnr = bufnr, severity = vim.diagnostic.severity.ERROR },
  } ---@type vim.Diagnostic[]
  ---@diagnostic disable-next-line: assign-type-mismatch
  local buffer_notifications = 0 ---@type integer
  local state = reset_state()
  ---@diagnostic disable-next-line: missing-fields
  Diagnostic._subscribers_bufnr[bufnr] = {
    notify = function()
      buffer_notifications = buffer_notifications + 1
    end,
  }
  t:patch_table(vim.diagnostic, "get", function(requested_bufnr)
    t.assert_eq(bufnr, requested_bufnr, "scoped diagnostic query")
    return diagnostics
  end)

  Diagnostic.refresh(bufnr)
  flush_refresh()
  t.assert_eq(1, state.notifications, "initial diagnostic")
  t.assert_eq(1, buffer_notifications, "initial buffer diagnostic")

  Diagnostic.refresh(bufnr)
  flush_refresh()
  t.assert_eq(1, state.notifications, "unchanged diagnostic")
  t.assert_eq(1, buffer_notifications, "unchanged buffer diagnostic")

  diagnostics = {
    { bufnr = bufnr, severity = vim.diagnostic.severity.WARN },
  }
  Diagnostic.refresh(bufnr)
  flush_refresh()
  t.assert_eq(2, state.notifications, "changed severity")
  t.assert_eq(2, buffer_notifications, "changed buffer severity")

  diagnostics = {}
  Diagnostic.refresh(bufnr)
  flush_refresh()
  t.assert_eq(3, state.notifications, "cleared diagnostic")
  t.assert_eq(3, buffer_notifications, "cleared buffer diagnostic")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("refresh: debounce retains every changed buffer", function()
  local bufnr1 = vim.api.nvim_create_buf(false, true) ---@type integer
  local bufnr2 = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_name(bufnr1, "diagnostic-pending-1.lua")
  vim.api.nvim_buf_set_name(bufnr2, "diagnostic-pending-2.lua")

  local calls = {} ---@type table<integer, integer>
  local state = reset_state()
  t:patch_table(vim.diagnostic, "get", function(bufnr)
    t.assert_true(bufnr ~= nil, "buffer-scoped diagnostic query")
    calls[bufnr] = (calls[bufnr] or 0) + 1
    if bufnr == bufnr1 then
      return { { severity = vim.diagnostic.severity.ERROR } }
    end
    return {
      { severity = vim.diagnostic.severity.WARN },
      { severity = vim.diagnostic.severity.WARN },
    }
  end)

  Diagnostic.refresh(bufnr1)
  Diagnostic.refresh(bufnr1)
  Diagnostic.refresh(bufnr2)
  t.assert_nil(calls[bufnr1], "queries before debounce flush")
  t.assert_nil(calls[bufnr2], "queries before debounce flush")

  flush_refresh()
  t.assert_eq(1, calls[bufnr1], "deduplicated first buffer")
  t.assert_eq(1, calls[bufnr2], "retained second buffer")
  t.assert_eq(1, state.notifications, "batched notification")

  local errors, warns, infos, hints = Diagnostic.get_totals()
  t.assert_eq(1, errors, "total errors")
  t.assert_eq(2, warns, "total warnings")
  t.assert_eq(0, infos, "total infos")
  t.assert_eq(0, hints, "total hints")

  vim.api.nvim_buf_delete(bufnr1, { force = true })
  vim.api.nvim_buf_delete(bufnr2, { force = true })
end)

t:test("refresh: aggregates every diagnostic namespace in the buffer", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_name(bufnr, "diagnostic-namespaces.lua")
  local ns1 = vim.api.nvim_create_namespace("diagnostic-test-namespace-1")
  local ns2 = vim.api.nvim_create_namespace("diagnostic-test-namespace-2")
  local state = reset_state()

  vim.diagnostic.set(ns1, bufnr, {
    { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
  })
  vim.diagnostic.set(ns2, bufnr, {
    { lnum = 0, col = 0, message = "warning", severity = vim.diagnostic.severity.WARN },
  })

  Diagnostic.refresh(bufnr)
  flush_refresh()
  local data = Diagnostic.get_by_bufnr(bufnr)
  t.assert_eq(2, data.total, "all namespaces")
  t.assert_eq(1, data.error, "namespace error")
  t.assert_eq(1, data.warn, "namespace warning")
  t.assert_eq(1, state.notifications, "initial namespaces")

  vim.diagnostic.reset(ns1, bufnr)
  Diagnostic.refresh(bufnr)
  flush_refresh()
  data = Diagnostic.get_by_bufnr(bufnr)
  t.assert_eq(1, data.total, "remaining namespace")
  t.assert_eq(0, data.error, "cleared namespace error")
  t.assert_eq(1, data.warn, "remaining namespace warning")
  t.assert_eq(2, state.notifications, "cleared namespace")

  vim.diagnostic.reset(ns2, bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("setup: buffer deletion removes totals and pending refreshes", function()
  local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
  vim.api.nvim_buf_set_name(bufnr, "diagnostic-delete.lua")
  local ns = vim.api.nvim_create_namespace("diagnostic-test-delete")
  vim.diagnostic.set(ns, bufnr, {
    { lnum = 0, col = 0, message = "error", severity = vim.diagnostic.severity.ERROR },
  })

  local state = reset_state()
  local buffer_notifications = 0 ---@type integer
  local disposals = 0 ---@type integer
  ---@diagnostic disable-next-line: missing-fields
  Diagnostic._subscribers_bufnr[bufnr] = {
    notify = function()
      buffer_notifications = buffer_notifications + 1
    end,
    dispose = function()
      disposals = disposals + 1
    end,
  }

  local diagnostic_changed ---@type fun(args: { buf: integer })|nil
  local buffer_deleted ---@type fun(args: { buf: integer })|nil
  t:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
    if events == "DiagnosticChanged" then
      diagnostic_changed = opts.callback
    else
      buffer_deleted = opts.callback
    end
    return 1
  end)

  Diagnostic.setup()
  t.assert_eq(1, state.notifications, "initial global diagnostic")
  t.assert_eq(1, buffer_notifications, "initial buffer diagnostic")
  t.assert_eq(1, select(1, Diagnostic.get_totals()), "initial total")

  assert(diagnostic_changed ~= nil, "missing DiagnosticChanged callback")
  assert(buffer_deleted ~= nil, "missing buffer deletion callback")
  diagnostic_changed({ buf = bufnr })
  buffer_deleted({ buf = bufnr })
  buffer_deleted({ buf = bufnr })
  flush_refresh()

  t.assert_eq(2, state.notifications, "deleted global diagnostic")
  t.assert_eq(1, buffer_notifications, "no deleted buffer notification")
  t.assert_eq(1, disposals, "subscriber disposal")
  t.assert_eq(0, select(1, Diagnostic.get_totals()), "deleted total")
  t.assert_nil(Diagnostic._buffers[bufnr], "deleted buffer cache")
  t.assert_nil(Diagnostic._subscribers_bufnr[bufnr], "deleted buffer subscribers")

  vim.diagnostic.reset(ns, bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
