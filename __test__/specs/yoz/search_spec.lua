local harness = require("__test__.support.harness")
local native = require("yoz")

local t = harness.new()

local function options()
  return {
    cwd = vim.fs.joinpath(vim.fn.getcwd(), "__test__/fixtures/yoz"),
    flag_case_sensitive = true,
    flag_gitignore = true,
    flag_regex = false,
    max_filesize = "1M",
    max_matches = 100,
    search_pattern = "Hello",
    search_paths = ".",
    include_patterns = "*.txt",
    exclude_patterns = "",
  }
end

t:test("native job matches synchronous ordered results and polls repeatedly", function()
  local expected, sync_err = native.search.search_in_files(options())
  t.assert_nil(sync_err)
  t.assert_true(expected ~= nil)

  local search_job = native.search.start_search_in_files(options())
  local status, result, err
  t.wait_until(function()
    status, result, err = search_job:poll()
    return status ~= "running"
  end, 5000, "native search job did not finish")

  t.assert_eq("completed", status)
  t.assert_nil(err)
  t.assert_same(expected.items, result.items, "ordered search items must match")

  local status_again, result_again, err_again = search_job:poll()
  t.assert_eq("completed", status_again)
  t.assert_nil(err_again)
  t.assert_same(result.items, result_again.items, "terminal poll must be idempotent")

  search_job:dispose()
  search_job:dispose()
  local ok = pcall(search_job.poll, search_job)
  t.assert_false(ok, "poll after dispose is misuse")
end)

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
