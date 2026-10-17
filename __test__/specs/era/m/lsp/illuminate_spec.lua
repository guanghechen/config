--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/lsp/illuminate_spec.lua
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.lsp.illuminate" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("era.m.lsp.illuminate")

bootstrap.with_stl(t, { nvim = { fn = require("stl.nvim.fn") } })
bootstrap.with_dot(t, {
  context = {
    flight = {
      dressing_illuminate = {
        snapshot = function()
          return true
        end,
      },
    },
  },
})

local Illuminate = require("era.m.lsp.illuminate")

t:test("Insert submode changes leave reference highlights alone", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local lookups = 0 ---@type integer
  local get_extmarks = vim.api.nvim_buf_get_extmarks
  t:patch_table(vim.lsp, "get_clients", function()
    return { {} }
  end)
  t:patch_table(vim.lsp.buf, "clear_references", function() end)
  t:patch_table(vim.lsp.buf, "document_highlight", function() end)
  t:patch_table(vim.api, "nvim_buf_get_extmarks", function(...)
    lookups = lookups + 1
    return get_extmarks(...)
  end)
  Illuminate.dressing(bufnr)
  t:defer(function()
    Illuminate.undressing(bufnr)
  end)

  for _, transition in ipairs({ "i:ic", "ic:i" }) do
    vim.api.nvim_exec_autocmds("ModeChanged", { pattern = transition, modeline = false })
  end
  t.assert_eq(0, lookups, "reference lookups within Insert mode")

  vim.api.nvim_exec_autocmds("ModeChanged", { pattern = "i:n", modeline = false })
  t.assert_eq(2, lookups, "reference lookups after leaving Insert mode")
end)

t:run()
