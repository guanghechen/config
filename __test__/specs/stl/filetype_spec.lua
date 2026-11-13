local harness = require("__test__.support.harness")

local t = harness.new()

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

t:test("printable files include text names without an extension but not binary or unknown ones", function()
  for _, name in ipairs({ "Makefile", "Dockerfile", "Justfile", "LICENSE", "init.lua" }) do
    t.assert_true(Filetype.is_printable_file(name), name)
  end
  for _, name in ipairs({ "image.png", "archive.zip", "blob" }) do
    t.assert_false(Filetype.is_printable_file(name), name)
  end
end)

t:test("picker and searcher finders take no completion", function()
  t.assert_false(Filetype.is_cmp_enabled(Filetype.UX_PICKER_FINDER), "picker finder")
  t.assert_false(Filetype.is_cmp_enabled(Filetype.UX_SEARCHER_FINDER), "searcher finder")
end)

t:test("surrounds stay out of interface buffers but not notes or code", function()
  for _, filetype in ipairs({
    Filetype.UX_PICKER_RESULT,
    Filetype.UX_PICKER_PREVIEW,
    Filetype.EXPLORER,
    Filetype.NOTIFY,
  }) do
    t.assert_false(Filetype.is_surround_enabled(filetype), filetype)
  end
  for _, filetype in ipairs({ Filetype.NOTEPAD, "lua", "" }) do
    t.assert_true(Filetype.is_surround_enabled(filetype), filetype)
  end
end)

t:test("Changes delegates dirty winline renders to its window-owned nvimbar", function()
  local filetype = assert(loadfile("lua/stl/filetype.lua"))()
  t.assert_true(filetype.has_external_winline(filetype.DIFFVIEW_CHANGES), "external Changes winline")
end)

t:run()
