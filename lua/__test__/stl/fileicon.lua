---@diagnostic disable: undefined-global
--- Test for stl.fileicon
--- Run with: nvim -l lua/__test__/stl/fileicon.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("stl.fileicon")

local Filetype = require("stl.filetype")
bootstrap.with_runtime(t, {
  stl = {
    filetype = Filetype,
  },
  yoz = {
    path = {
      basename = function(filepath)
        return filepath
      end,
    },
  },
})

local Fileicon = require("stl.fileicon")

t:test("get_file_icon: empty filetype skips automatic detection", function()
  local detect_calls = 0 ---@type integer
  t:patch_table(stl.filetype, "detect", function()
    detect_calls = detect_calls + 1
    return "lua"
  end)

  local filename = "__fileicon_detection_probe__" ---@type string
  Fileicon.get_file_icon(filename, "")
  t.assert_eq(0, detect_calls, "explicit empty filetype")

  Fileicon.get_file_icon(filename)
  t.assert_eq(1, detect_calls, "missing filetype should use automatic detection")
end)

t:run()
