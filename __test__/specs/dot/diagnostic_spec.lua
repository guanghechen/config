--- Run with: nvim -l __test__/run.lua __test__/specs/dot/diagnostic_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("dot.diagnostic")

bootstrap.with_runtime(t, {
  stl = {
    nvim = {
      fn = {
        augroup = function(name)
          return vim.api.nvim_create_augroup(name, { clear = true })
        end,
      },
    },
  },
})

local Diagnostic = require("dot.diagnostic")
local namespace = vim.api.nvim_create_namespace("__test__.dot.diagnostic") ---@type integer

---@param bufnr                         integer
---@return string
local function virtual_text_rows(bufnr)
  local virt_text_ns = vim.diagnostic.get_namespace(namespace).user_data.virt_text_ns ---@type integer
  local rows = {} ---@type integer[]
  for _, extmark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, virt_text_ns, 0, -1, { details = true })) do
    if extmark[4].virt_text ~= nil then
      rows[#rows + 1] = extmark[2]
    end
  end
  return table.concat(rows, ",")
end

---@param bufnr                         integer
---@return nil
local function publish(bufnr)
  local diagnostics = {} ---@type vim.Diagnostic[]
  for _, lnum in ipairs({ 0, 2, 4 }) do
    diagnostics[#diagnostics + 1] = { lnum = lnum, col = 0, message = "problem " .. lnum, severity = 1 }
  end
  vim.diagnostic.set(namespace, bufnr, diagnostics)
end

---@param row                           integer
---@return nil
local function move(row)
  vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { modeline = false })
end

t:test("virtual text leaves the cursor line and only the rows involved change", function()
  local config = vim.diagnostic.config() ---@type vim.diagnostic.Opts
  t:defer(function()
    vim.diagnostic.config(config)
  end)
  vim.diagnostic.config({ virtual_text = true, virtual_lines = false, signs = false, underline = false })
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "a", "b", "c", "d", "e", "f" })
  vim.api.nvim_win_set_cursor(winnr, { 3, 0 })

  Diagnostic.set_virtual_text_hides_cursor_line(true)
  publish(bufnr)
  t.assert_eq("0,4", virtual_text_rows(bufnr), "cursor on a diagnostic row")

  local clears = 0 ---@type integer
  local clear_namespace = vim.api.nvim_buf_clear_namespace
  t:patch_table(vim.api, "nvim_buf_clear_namespace", function(...)
    clears = clears + 1
    return clear_namespace(...)
  end)
  move(4)
  t.assert_eq("0,2", virtual_text_rows(bufnr), "moved to another diagnostic row")
  move(3)
  t.assert_eq("0,2,4", virtual_text_rows(bufnr), "moved to a row without diagnostics")
  move(0)
  t.assert_eq("2,4", virtual_text_rows(bufnr), "moved to the first row")
  t.assert_eq(0, clears, "moves render nothing again")

  publish(bufnr)
  t.assert_eq("2,4", virtual_text_rows(bufnr), "a new publication keeps the cursor line clear")

  Diagnostic.set_virtual_text_hides_cursor_line(false)
  t.assert_eq("0,2,4", virtual_text_rows(bufnr), "switched off")
  move(2)
  t.assert_eq("0,2,4", virtual_text_rows(bufnr), "moves while switched off")
end)

t:run()
