local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local Diagnostic = require("era.m.lsp.diagnostic")

local ROOT = vim.uv.cwd() .. "/__test__/local.diagnostic-render" ---@type string
local severity = vim.diagnostic.severity

---@return era.m.lsp.diagnostic.Store
local function new_store()
  local store = Diagnostic.Store.new({ debounce_ms = 10, on_change = function() end })
  t:defer(function()
    store:dispose()
  end)
  return store
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
  vim.api.nvim_buf_set_name(bufnr, name)
  return bufnr
end

local ns = vim.api.nvim_create_namespace("diagnostic-render-spec") ---@type integer

---@param bufnr                         integer
---@param severities                    vim.diagnostic.Severity[]
---@return nil
local function set(bufnr, severities)
  local diagnostics = {} ---@type vim.Diagnostic.Set[]
  for index, value in ipairs(severities) do
    diagnostics[index] = { lnum = 0, col = 0, message = "diagnostic " .. index, severity = value }
  end
  vim.diagnostic.set(ns, bufnr, diagnostics)
  t:defer(function()
    vim.diagnostic.reset(ns)
  end)
end

---@param store                         era.m.lsp.diagnostic.Store
---@param filepath                      string
---@return string
local function render(store, filepath)
  local found = store:find(filepath) ---@type era.m.lsp.diagnostic.IBufferDiagnostics|nil
  return found ~= nil and Diagnostic.format(found, 0, {}) or ""
end

-- What render showed when it located the buffer among every buffer.
---@param store                         era.m.lsp.diagnostic.Store
---@param filepath                      string
---@return string
local function expected(store, filepath)
  local bufnr = stl.nvim.buf.locate_bufnr(filepath) ---@type integer|nil
  return bufnr ~= nil and Diagnostic.format(store:get(bufnr), 0, {}) or ""
end

---@param store                         era.m.lsp.diagnostic.Store
---@param paths                         string[]
---@return nil
local function assert_matches_locate(store, paths)
  for _, filepath in ipairs(paths) do
    t.assert_eq(expected(store, filepath), render(store, filepath), "render " .. filepath)
  end
end

for _, case in ipairs({
  { name = "no counts render nothing", counts = {}, offset = 0, parts = {} },
  {
    name = "counts render in error, warning, hint, info order",
    counts = { error = 1, warn = 2, info = 3, hint = 4 },
    offset = 0,
    parts = {
      { "Error_alt", 1, "f_lsp_diagnostic_error" },
      { "Warning_alt", 2, "f_lsp_diagnostic_warn" },
      { "Hint_alt", 4, "f_lsp_diagnostic_hint" },
      { "Information_alt", 3, "f_lsp_diagnostic_info" },
    },
  },
  {
    name = "zero counts are skipped and highlights start at the offset",
    counts = { error = 1, info = 2 },
    offset = 3,
    parts = { { "Error_alt", 1, "f_lsp_diagnostic_error" }, { "Information_alt", 2, "f_lsp_diagnostic_info" } },
  },
}) do
  t:test("format: " .. case.name, function()
    local counts = case.counts
    ---@type era.m.lsp.diagnostic.IBufferDiagnostics
    local data = {
      bufnr = 1,
      error = counts.error or 0,
      warn = counts.warn or 0,
      info = counts.info or 0,
      hint = counts.hint or 0,
    }
    local prior = { coll = 0, colr = case.offset, hlname = "prior" } ---@type stl.t.IHighlightInline
    local highlights = { prior } ---@type stl.t.IHighlightInline[]
    local text = Diagnostic.format(data, case.offset, highlights)

    local expected_text, expected_highlights = "", { prior }
    for _, part in ipairs(case.parts) do
      local piece = " " .. stl.icon.diagnostic[part[1]] .. " " .. part[2]
      local coll = case.offset + #expected_text
      expected_highlights[#expected_highlights + 1] = { coll = coll, colr = coll + #piece, hlname = part[3] }
      expected_text = expected_text .. piece
    end
    t.assert_eq(expected_text, text, "text")
    t.assert_same(expected_highlights, highlights, "highlights follow the existing ones")
  end)
end

t:test("find: matches the lookup among every buffer", function()
  local store = new_store()
  local counted = named_buffer(ROOT .. "/counted.lua")
  local zero = named_buffer(ROOT .. "/zero.lua")
  named_buffer(ROOT .. "/untracked.lua")
  local uri = named_buffer("diffview://" .. ROOT .. "/counted.lua")
  local wiped = named_buffer(ROOT .. "/wiped.lua")
  for index = 1, 20 do
    named_buffer(ROOT .. "/other/" .. index .. ".lua")
  end
  set(counted, { severity.ERROR, severity.ERROR, severity.WARN })
  set(zero, { severity.ERROR })
  set(uri, { severity.HINT, severity.HINT, severity.HINT })
  set(wiped, { severity.INFO, severity.INFO, severity.INFO, severity.INFO })
  store:refresh_all()
  -- A buffer whose diagnostics cleared keeps zero counts; a buffer wiped without telling the store keeps its own.
  set(zero, {})
  store:refresh_all()
  vim.api.nvim_buf_delete(wiped, { force = true })

  t.assert_true(render(store, ROOT .. "/counted.lua") ~= "", "a counted buffer renders its counts")
  t.assert_eq(0, store:get(zero).error, "zero counts")
  assert_matches_locate(store, {
    ROOT .. "/counted.lua",
    ROOT .. "/./counted.lua",
    ROOT .. "//counted.lua",
    ROOT .. "/zero.lua",
    ROOT .. "/untracked.lua",
    ROOT .. "/missing.lua",
    "diffview://" .. ROOT .. "/counted.lua",
    ROOT .. "/wiped.lua",
    ROOT .. "/other/1.lua",
    "",
  })
end)

t:test("find: a renamed buffer renders under its new name only", function()
  local store = new_store()
  local bufnr = named_buffer(ROOT .. "/before.lua")
  set(bufnr, { severity.WARN, severity.WARN, severity.WARN, severity.WARN, severity.WARN })
  store:refresh_all()
  local text = render(store, ROOT .. "/before.lua")
  t.assert_true(text ~= "", "renders before the rename")

  vim.api.nvim_buf_set_name(bufnr, ROOT .. "/after.lua")
  t.assert_eq("", render(store, ROOT .. "/before.lua"), "old name")
  t.assert_eq(text, render(store, ROOT .. "/after.lua"), "new name")
  assert_matches_locate(store, { ROOT .. "/before.lua", ROOT .. "/after.lua" })
end)

t:test("find: compares names without locating among every buffer", function()
  local store = new_store()
  local bufnr = named_buffer(ROOT .. "/fast.lua")
  set(bufnr, { severity.ERROR })
  store:refresh_all()
  local calls = 0
  local locate = stl.nvim.buf.locate_bufnr
  t:patch_table(stl.nvim.buf, "locate_bufnr", function(filepath)
    calls = calls + 1
    return locate(filepath)
  end)

  t.assert_true(store:find(ROOT .. "/fast.lua") ~= nil, "counted buffer")
  t.assert_nil(store:find(ROOT .. "/missing.lua"), "missing buffer")
  t.assert_eq(0, calls, "full lookups")
end)

t:test("find: Windows names keep the full lookup", function()
  local store = new_store()
  local bufnr = named_buffer(ROOT .. "/windows.lua")
  set(bufnr, { severity.ERROR })
  store:refresh_all()
  t:patch_table(stl.env, "IS_WIN", true)
  local calls = 0
  t:patch_table(stl.nvim.buf, "locate_bufnr", function()
    calls = calls + 1
    return bufnr
  end)

  t.assert_true(store:find("C:\\Project\\Windows.lua") ~= nil, "located buffer")
  t.assert_eq(1, calls, "full lookups")
end)

t:run()
