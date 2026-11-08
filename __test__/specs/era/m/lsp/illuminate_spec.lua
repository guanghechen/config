local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new()

local enabled = true ---@type boolean
local observers = {} ---@type fun()[]

bootstrap.with_global(t, "stl", {
  nvim = { fn = require("stl.nvim.fn") },
  fn = {
    observe = function(_, callback)
      observers[#observers + 1] = callback
    end,
  },
})
bootstrap.with_global(t, "dot", {
  context = {
    flight = {
      dressing_illuminate = {
        snapshot = function()
          return enabled
        end,
      },
    },
  },
})

local Illuminate = require("era.m.lsp.illuminate")

---@param value                         boolean
---@return nil
local function toggle(value)
  enabled = value
  for _, observer in ipairs(observers) do
    observer()
  end
end

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

t:test("the toggle detaches and attaches again the buffers attached before it changed", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local lookups, cleared = 0, {} ---@type integer, integer[]
  local get_extmarks = vim.api.nvim_buf_get_extmarks
  t:patch_table(vim.lsp, "get_clients", function()
    return { {} }
  end)
  t:patch_table(vim.lsp.util, "buf_clear_references", function(target)
    cleared[#cleared + 1] = target
  end)
  t:patch_table(vim.lsp.buf, "clear_references", function() end)
  t:patch_table(vim.lsp.buf, "document_highlight", function() end)
  t:patch_table(vim.api, "nvim_buf_get_extmarks", function(...)
    lookups = lookups + 1
    return get_extmarks(...)
  end)
  Illuminate.dressing(bufnr)
  t:defer(function()
    enabled = true
    Illuminate.undressing(bufnr)
  end)

  toggle(false)
  t.assert_same({ bufnr }, cleared, "references cleared in the attached buffer")
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr, modeline = false })
  t.assert_eq(0, lookups, "reference lookups while off")

  toggle(true)
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr, modeline = false })
  t.assert_true(lookups > 0, "reference lookups once on again")
end)

t:run()
