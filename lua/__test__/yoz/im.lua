---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/yoz/im.lua

local harness = require("__test__.harness")
local native = require("yoz")

local t = harness.new("yoz.im")
local sysname = vim.uv.os_uname().sysname

if sysname == "Darwin" then
  t:test("captures the current source", function()
    local source_id, current_err = native.im.current()
    local snapshot, capture_err = native.im.capture()

    t.assert_true(type(source_id) == "string" and source_id ~= "", "current source")
    t.assert_nil(current_err, "current error")
    t.assert_eq(source_id, snapshot, "captured source")
    t.assert_nil(capture_err, "capture error")
  end)

  t:test("maps semantic input methods", function()
    t.assert_true(native.im.is_input_method("com.apple.keylayout.ABC", "English"), "English source mapping")
    t.assert_true(native.im.is_input_method("com.apple.inputmethod.SCIM.ITABC", "Chinese"), "Chinese source mapping")
    t.assert_false(
      native.im.is_input_method("com.apple.inputmethod.Kotoeri.Japanese", "Chinese"),
      "unknown source mapping"
    )

    local selected, err = native.im.set_input_method("Japanese")
    t.assert_nil(selected, "invalid semantic selection")
    t.assert_true(type(err) == "string" and err:find("Unknown input method", 1, true) ~= nil, "selection error")
  end)

  t:test("rejects unknown source without changing current source", function()
    local before = native.im.current()
    local selected, err = native.im.select("dev.yoz.im.does-not-exist")
    local after = native.im.current()

    t.assert_nil(selected, "select result")
    t.assert_true(type(err) == "string" and err:find("not found", 1, true) ~= nil, "select error")
    t.assert_eq(before, after, "current source")
  end)
elseif sysname == "Windows_NT" then
  t:test("reads current input locale when a foreground window exists", function()
    local source_id, err = native.im.current()
    if source_id ~= nil then
      t.assert_true(source_id:match("^%d+$") ~= nil, "current input locale")
      t.assert_nil(err, "current error")
    else
      t.assert_true(type(err) == "string" and err ~= "", "current error")
    end
  end)

  t:test("maps full input locales", function()
    t.assert_true(native.im.is_input_method("67699721", "English"), "English HKL mapping")
    t.assert_true(native.im.is_input_method("134481924", "Chinese"), "Chinese HKL mapping")
    t.assert_false(native.im.is_input_method("134481924", "English"), "mismatched HKL mapping")
  end)

  t:test("rejects invalid input locale before posting a request", function()
    local selected, err = native.im.select("invalid")

    t.assert_nil(selected, "select result")
    t.assert_true(type(err) == "string" and err:find("Invalid Windows input locale", 1, true) ~= nil, "select error")
  end)
elseif sysname == "Linux" and vim.fn.has("wsl") == 1 then
  t:test("configures the helper and maps Windows language IDs", function()
    t.assert_true(native.im ~= nil, "IM capability")
    t.assert_true(native.im.setup ~= nil, "WSL setup capability")
    t.assert_true(native.im.is_input_method("1033", "English"), "English language mapping")
    t.assert_true(native.im.is_input_method("2052", "Chinese"), "Chinese language mapping")

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
