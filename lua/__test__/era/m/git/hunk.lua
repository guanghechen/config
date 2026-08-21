---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/git/hunk.lua

local harness = require("__test__.harness")
local diff = require("era.m.git.diff")
local hunk = assert(loadfile("lua/era/m/git/hunk.lua"))()

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

t:test("textobject: returns linewise unstaged hunk regions", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local modified = { "one", "TWO", "THREE", "four", "six" }
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, modified)
  hunk.set(bufnr, diff.run_diff({ "one", "two", "three", "four", "five", "six" }, modified))

  local regions ---@type table[]
  vim.api.nvim_buf_call(bufnr, function()
    regions = hunk.ai_textobject()
  end)
  hunk.remove(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })

  t.assert_eq(2, #regions, "regions")
  t.assert_eq(2, regions[1].from.line, "first start")
  t.assert_eq(3, regions[1].to.line, "first end")
  t.assert_eq(5, regions[1].to.col, "last byte column")
  t.assert_eq("V", regions[1].vis_mode, "linewise")
  t.assert_eq(4, regions[2].from.line, "second start")
end)

t:test("textobject: anchors a pure deletion to a selectable line", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "next" })
  hunk.set(bufnr, diff.run_diff({ "gone", "next" }, { "next" }))

  local regions ---@type table[]
  vim.api.nvim_buf_call(bufnr, function()
    regions = hunk.ai_textobject()
  end)
  hunk.remove(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })

  t.assert_eq(1, regions[1].from.line, "top deletion anchor")
  t.assert_eq(1, regions[1].to.line, "single anchor line")
  t.assert_eq("V", regions[1].vis_mode, "linewise")
end)

t:run()
