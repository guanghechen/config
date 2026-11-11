local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

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
---@return string
local function virtual_text_messages(bufnr)
  local virt_text_ns = vim.diagnostic.get_namespace(namespace).user_data.virt_text_ns ---@type integer
  local messages = {} ---@type string[]
  for _, extmark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, virt_text_ns, 0, -1, { details = true })) do
    local text = "" ---@type string
    for _, chunk in ipairs(extmark[4].virt_text or {}) do
      text = text .. chunk[1]
    end
    local message = text:match("problem %d+") ---@type string|nil
    if message ~= nil then
      messages[#messages + 1] = extmark[2] .. "=" .. message
    end
  end
  return table.concat(messages, " ")
end

---@param bufnr                         integer
---@param rows                          ?integer[]
---@return nil
local function publish(bufnr, rows)
  local diagnostics = {} ---@type vim.Diagnostic[]
  for _, lnum in ipairs(rows or { 0, 2, 4 }) do
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

---Shows a scratch buffer holding `lines` in the current window, with virtual text the only diagnostic display.
---@param lines                         string[]
---@return integer winnr
---@return integer bufnr
local function show_scratch(lines)
  local config = vim.diagnostic.config() ---@type vim.diagnostic.Opts
  t:defer(function()
    vim.diagnostic.config(config)
    Diagnostic.set_virtual_text_hides_cursor_line(false)
  end)
  vim.diagnostic.config({ virtual_text = true, virtual_lines = false, signs = false, underline = false })
  return vim.api.nvim_get_current_win(), t:buffer(lines, { current = true })
end

t:test("virtual text leaves the cursor line and only the rows involved change", function()
  local winnr, bufnr = show_scratch({ "a", "b", "c", "d", "e", "f" })
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

t:test("a republication keeps every message on its own row", function()
  local winnr, bufnr = show_scratch({ "a", "b", "c", "d", "e", "f", "g" })
  Diagnostic.set_virtual_text_hides_cursor_line(true)
  for _, cursor_row in ipairs({ 0, 2, 4 }) do
    vim.api.nvim_win_set_cursor(winnr, { cursor_row + 1, 0 })
    publish(bufnr)
    local remaining = vim.tbl_filter(function(row)
      return row ~= cursor_row
    end, { 0, 2, 4 })
    publish(bufnr, remaining)
    local expected = table.concat(
      vim.tbl_map(function(row)
        return row .. "=problem " .. row
      end, remaining),
      " "
    )
    t.assert_eq(expected, virtual_text_messages(bufnr), "fixed row " .. cursor_row)
    move(6)
    t.assert_eq(expected, virtual_text_messages(bufnr), "moved away from fixed row " .. cursor_row)
  end
end)

t:test("a republication while another window is current still hides the cursor line on return", function()
  local winnr, bufnr = show_scratch({ "a", "b", "c", "d", "e", "f" })
  vim.api.nvim_win_set_cursor(winnr, { 3, 0 })
  Diagnostic.set_virtual_text_hides_cursor_line(true)
  publish(bufnr)
  t.assert_eq("0,4", virtual_text_rows(bufnr), "cursor on a diagnostic row")

  t:window(t:buffer(), { split = "below" }, true)
  vim.api.nvim_exec_autocmds("CursorMoved", { modeline = false })
  publish(bufnr)

  vim.api.nvim_set_current_win(winnr)
  vim.api.nvim_exec_autocmds("CursorMoved", { modeline = false })
  t.assert_eq("0,4", virtual_text_rows(bufnr), "cursor line hidden again")
end)

t:run()
