--- Run with: nvim -l __test__/run.lua __test__/specs/yoz/im_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
local native = require("yoz")

local t = harness.new("yoz.im")
local sysname = vim.uv.os_uname().sysname

if native.im ~= nil then
  t:test("exports only the source-oriented contract", function()
    t.assert_eq("function", type(native.im.capture), "capture")
    t.assert_eq("function", type(native.im.capture_and_select_english), "capture and select English")
    t.assert_eq("function", type(native.im.restore), "restore")
    t.assert_eq("function", type(native.im.is_english), "English predicate")
    t.assert_nil(native.im.current, "legacy current")
    t.assert_nil(native.im.select, "legacy select")
    t.assert_nil(native.im.is_input_method, "legacy input method predicate")
    t.assert_nil(native.im.get_input_method, "legacy input method getter")
    t.assert_nil(native.im.set_input_method, "legacy input method setter")
  end)
end

if sysname == "Darwin" then
  t:test("captures and restores an exact TIS source ID", function()
    local snapshot, capture_err = native.im.capture()

    t.assert_true(type(snapshot) == "string" and snapshot ~= "", "captured source")
    t.assert_nil(capture_err, "capture error")

    local restored, restore_err = native.im.restore(snapshot)
    t.assert_true(restored, "restore result")
    t.assert_nil(restore_err, "restore error")
  end)
elseif sysname == "Windows_NT" then
  t:test("classifies English variants from full HKLs", function()
    t.assert_true(native.im.is_english("67699721"), "English US HKL")
    t.assert_true(native.im.is_english("134809609"), "English UK HKL")
    t.assert_false(native.im.is_english("134481924"), "non-English HKL")
    t.assert_false(native.im.is_english("invalid"), "invalid HKL")
  end)

  t:test("rejects an invalid restore target", function()
    local restored, err = native.im.restore("invalid")

    t.assert_nil(restored, "restore result")
    t.assert_true(type(err) == "string" and err:find("Invalid Windows input locale", 1, true) ~= nil, "restore error")
  end)
elseif sysname == "Linux" and vim.fn.has("wsl") == 1 then
  t:test("configures the helper and classifies English variants", function()
    t.assert_true(native.im.setup ~= nil, "WSL setup capability")
    t.assert_true(native.im.is_english("1033"), "English US language ID")
    t.assert_true(native.im.is_english("2057"), "English UK language ID")
    t.assert_true(native.im.is_english("67699721"), "English full HKL")
    t.assert_false(native.im.is_english("1041"), "non-English language ID")
    t.assert_false(native.im.is_english("134481924"), "non-English full HKL")

    local configured, err = native.im.setup({ executable = "" })
    t.assert_nil(configured, "invalid setup result")
    t.assert_true(type(err) == "string" and err:find("must not be empty", 1, true) ~= nil, "setup error")
  end)
else
  t:test("is unavailable on unsupported platforms", function()
    t.assert_nil(native.im, "IM capability")
  end)
end

t:run()
