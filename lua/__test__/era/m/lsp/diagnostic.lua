---@diagnostic disable: undefined-global, invisible
--- Test for era.m.lsp.diagnostic module
--- Run with: nvim -l lua/__test__/era/m/lsp/diagnostic.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.lsp.diagnostic")

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
          return { notify = function() end }
        end,
      },
    },
    timer = {
      debounce = function(callback)
        return callback
      end,
    },
  },
})

local Diagnostic = require("era.m.lsp.diagnostic")

t:test("refresh: unchanged counts do not notify global subscribers", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_name(bufnr, "diagnostic-false-notification-test.lua")

  local diagnostics = {
    { bufnr = bufnr, severity = vim.diagnostic.severity.ERROR },
  } ---@type vim.Diagnostic[]
  local notifications = 0 ---@type integer

  t:patch_table(Diagnostic, "_buffers", {})
  t:patch_table(Diagnostic, "_subscribers_bufnr", {})
  t:patch_table(Diagnostic, "_subscribers_all", {
    notify = function()
      notifications = notifications + 1
    end,
  })
  t:patch_table(Diagnostic, "_total_error", 0)
  t:patch_table(Diagnostic, "_total_warn", 0)
  t:patch_table(Diagnostic, "_total_info", 0)
  t:patch_table(Diagnostic, "_total_hint", 0)
  t:patch_table(vim.diagnostic, "get", function()
    return diagnostics
  end)

  Diagnostic.refresh()
  t.assert_eq(1, notifications, "initial diagnostic")

  Diagnostic.refresh()
  t.assert_eq(1, notifications, "unchanged diagnostic")

  diagnostics = {
    { bufnr = bufnr, severity = vim.diagnostic.severity.WARN },
  }
  Diagnostic.refresh()
  t.assert_eq(2, notifications, "changed severity")

  diagnostics = {}
  Diagnostic.refresh()
  t.assert_eq(3, notifications, "cleared diagnostic")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
