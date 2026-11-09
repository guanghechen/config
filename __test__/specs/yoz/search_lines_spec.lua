local harness = require("__test__.support.harness")
local native = require("yoz")

local t = harness.new()

t:test("line search locates the matches it lists, without their previews", function()
  local options = {
    pattern = "o",
    lines = { "foo", "", "bar o" },
    flag_fuzzy = false,
    flag_regex = false,
    flag_case_sensitive = true,
  }
  local listed = assert(native.search.search_in_lines(options))
  local located = assert(native.search.locate_in_lines(options))

  local expected = {} ---@type yoz.search.ITextRange[]
  for i, match in ipairs(listed.matches) do
    expected[i] = { lx = match.lx, ly = match.ly, cx = match.cx, cy = match.cy, ox = match.ox, oy = match.oy }
  end
  t.assert_eq(3, #expected, "the matches listed")
  t.assert_same(expected, located.matches, "the same places, and nothing else of them")
  t.assert_same({ "elapsed_time", "matches" }, vim.fn.sort(vim.tbl_keys(located)), "no matches of each line")

  local _, err = native.search.locate_in_lines(vim.tbl_extend("force", options, { pattern = "(", flag_regex = true }))
  t.assert_true(type(err) == "string", "an invalid pattern tells why")
end)

t:run()
