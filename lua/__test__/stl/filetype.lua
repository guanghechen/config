---@diagnostic disable: undefined-global
--- Test for stl.filetype
--- Run with: nvim -l lua/__test__/stl/filetype.lua

local harness = require("__test__.harness")

local t = harness.new("stl.filetype")

local Filetype = require("stl.filetype")

t:test("detect: matches by filename without a buffer", function()
  local received = nil ---@type table|nil
  t:patch_table(vim.filetype, "match", function(opts)
    received = opts
    return "lua"
  end)

  local result = Filetype.detect("init.lua") ---@type string|nil

  t.assert_eq("lua", result, "detected filetype")
  t.assert_true(received ~= nil, "match options")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("init.lua", received.filename, "filename")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_nil(received.buf, "buffer")
end)

t:test("C# uses Neovim's cs filetype", function()
  t.assert_true(Filetype.is_cmp_enabled("cs"), "completion")
  t.assert_true(Filetype.is_language("cs"), "language")
  t.assert_false(Filetype.is_cmp_enabled("csharp"), "nonexistent alias")
end)

t:test("indentscope is enabled only for eligible source filetypes", function()
  t.assert_true(Filetype.is_indentscope_enabled("lua"), "lua")
  t.assert_false(Filetype.is_indentscope_enabled(Filetype.BIGFILE), "bigfile")
  t.assert_false(Filetype.is_indentscope_enabled("diff"), "diff")
  t.assert_false(Filetype.is_indentscope_enabled(Filetype.BOARD), "board")
  t.assert_false(Filetype.is_indentscope_enabled(""), "empty")
  t.assert_false(Filetype.is_indentscope_enabled(nil), "nil")
end)

t:run()
