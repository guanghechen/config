---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/git/hunk.lua

local harness = require("__test__.harness")
local diff = require("era.m.git.diff")
local hunk = require("era.m.git.hunk")

local t = harness.new("era.m.git.hunk")

t:test("signs: a following deletion does not rewrite a change sign", function()
  local hunks = diff.run_diff({ "a", "b", "c", "" }, { "A", "b", "" })
  local signs = hunk.calc_signs_all(hunks)

  t.assert_eq(2, #hunks, "authoritative hunks")
  t.assert_eq("change", signs[1].type, "change sign")
  t.assert_eq(1, signs[1].lnum, "change line")
  t.assert_eq("delete", signs[2].type, "delete sign")
  t.assert_eq(2, signs[2].lnum, "delete anchor")
end)

t:test("signs: excess removed lines remain a changedelete", function()
  local hunks = diff.run_diff({ "a", "b", "c", "" }, { "A", "" })
  local signs = hunk.calc_signs_all(hunks)

  t.assert_eq(1, #hunks, "one unequal hunk")
  t.assert_eq("changedelete", signs[1].type, "combined sign")
end)

t:run()
