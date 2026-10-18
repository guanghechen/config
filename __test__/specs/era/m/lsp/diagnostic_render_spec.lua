--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/lsp/diagnostic_render_spec.lua
---@diagnostic disable: undefined-global, invisible

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m.lsp.diagnostic.render")
local Diagnostic = require("era.m.lsp.diagnostic")

local ROOT = vim.uv.cwd() .. "/__test__/local.diagnostic-render" ---@type string

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

---@param bufnr                         integer
---@param counts                        { error?: integer, warn?: integer, info?: integer, hint?: integer }
---@return era.m.lsp.diagnostic.IBufferDiagnostics
local function data(bufnr, counts)
  local error, warn, info, hint = counts.error or 0, counts.warn or 0, counts.info or 0, counts.hint or 0
  return { bufnr = bufnr, error = error, warn = warn, info = info, hint = hint, total = error + warn + info + hint }
end

-- What render showed when it located the buffer among every buffer.
---@param filepath                      string
---@return string
local function expected(filepath)
  local bufnr = stl.nvim.buf.locate_bufnr(filepath) ---@type integer|nil
  local found = bufnr ~= nil and Diagnostic._buffers[bufnr] or nil
  if found == nil then
    return ""
  end
  local icons = stl.icon.diagnostic
  local text = "" ---@type string
  for _, part in ipairs({
    { found.error, icons.Error_alt },
    { found.warn, icons.Warning_alt },
    { found.hint, icons.Hint_alt },
    { found.info, icons.Information_alt },
  }) do
    if part[1] > 0 then
      text = text .. " " .. part[2] .. " " .. part[1]
    end
  end
  return text
end

---@param paths                         string[]
---@return nil
local function assert_matches_locate(paths)
  for _, filepath in ipairs(paths) do
    t.assert_eq(expected(filepath), Diagnostic.render(filepath, 0, {}), "render " .. filepath)
  end
end

t:test("render: matches the lookup among every buffer", function()
  local counted = named_buffer(ROOT .. "/counted.lua")
  local zero = named_buffer(ROOT .. "/zero.lua")
  named_buffer(ROOT .. "/untracked.lua")
  local uri = named_buffer("diffview://" .. ROOT .. "/counted.lua")
  local wiped = named_buffer(ROOT .. "/wiped.lua")
  for index = 1, 20 do
    named_buffer(ROOT .. "/other/" .. index .. ".lua")
  end
  t:patch_table(Diagnostic, "_buffers", {
    [counted] = data(counted, { error = 2, warn = 1 }),
    [zero] = data(zero, {}),
    [uri] = data(uri, { hint = 3 }),
    [wiped] = data(wiped, { info = 4 }),
  })
  vim.api.nvim_buf_delete(wiped, { force = true })

  local text = Diagnostic.render(ROOT .. "/counted.lua", 0, {})
  t.assert_true(text ~= "", "a counted buffer renders its counts")
  assert_matches_locate({
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

t:test("render: a renamed buffer renders under its new name only", function()
  local bufnr = named_buffer(ROOT .. "/before.lua")
  t:patch_table(Diagnostic, "_buffers", { [bufnr] = data(bufnr, { warn = 5 }) })
  local text = Diagnostic.render(ROOT .. "/before.lua", 0, {})
  t.assert_true(text ~= "", "renders before the rename")

  vim.api.nvim_buf_set_name(bufnr, ROOT .. "/after.lua")
  t.assert_eq("", Diagnostic.render(ROOT .. "/before.lua", 0, {}), "old name")
  t.assert_eq(text, Diagnostic.render(ROOT .. "/after.lua", 0, {}), "new name")
  assert_matches_locate({ ROOT .. "/before.lua", ROOT .. "/after.lua" })
end)

t:test("render: highlights cover each count", function()
  local bufnr = named_buffer(ROOT .. "/highlights.lua")
  t:patch_table(Diagnostic, "_buffers", { [bufnr] = data(bufnr, { error = 1, info = 2 }) })
  local highlights = {} ---@type stl.t.IHighlightInline[]
  local text = Diagnostic.render(ROOT .. "/highlights.lua", 3, highlights)

  t.assert_eq(2, #highlights, "highlight count")
  t.assert_eq("f_lsp_diagnostic_error", highlights[1].hlname, "error highlight")
  t.assert_eq("f_lsp_diagnostic_info", highlights[2].hlname, "info highlight")
  t.assert_eq(3, highlights[1].coll, "starts at the offset")
  t.assert_eq(3 + #text, highlights[2].colr, "ends with the text")
end)

t:test("render: compares names without locating among every buffer", function()
  local bufnr = named_buffer(ROOT .. "/fast.lua")
  t:patch_table(Diagnostic, "_buffers", { [bufnr] = data(bufnr, { error = 1 }) })
  local calls = 0
  local locate = stl.nvim.buf.locate_bufnr
  t:patch_table(stl.nvim.buf, "locate_bufnr", function(filepath)
    calls = calls + 1
    return locate(filepath)
  end)

  t.assert_true(Diagnostic.render(ROOT .. "/fast.lua", 0, {}) ~= "", "counted buffer")
  t.assert_eq("", Diagnostic.render(ROOT .. "/missing.lua", 0, {}), "missing buffer")
  t.assert_eq(0, calls, "full lookups")
end)

t:test("render: Windows names keep the full lookup", function()
  local bufnr = named_buffer(ROOT .. "/windows.lua")
  t:patch_table(Diagnostic, "_buffers", { [bufnr] = data(bufnr, { error = 1 }) })
  t:patch_table(stl.env, "IS_WIN", true)
  local calls = 0
  t:patch_table(stl.nvim.buf, "locate_bufnr", function()
    calls = calls + 1
    return bufnr
  end)

  t.assert_true(Diagnostic.render("C:\\Project\\Windows.lua", 0, {}) ~= "", "located buffer")
  t.assert_eq(1, calls, "full lookups")
end)

t:run()
