--- Run with: nvim -l lua/__test__/yoz/search_job.lua

local harness = require("__test__.harness")
local native = require("yoz")

local t = harness.new("yoz.search job")

local function options()
  return {
    cwd = vim.fs.joinpath(vim.fn.getcwd(), "rust/yoz/tests/fixtures"),
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
  t.assert_true(vim.deep_equal(expected.items, result.items), "ordered search items must match")

  local status_again, result_again, err_again = search_job:poll()
  t.assert_eq("completed", status_again)
  t.assert_nil(err_again)
  t.assert_true(vim.deep_equal(result.items, result_again.items), "terminal poll must be idempotent")

  search_job:dispose()
  search_job:dispose()
  local ok = pcall(search_job.poll, search_job)
  t.assert_false(ok, "poll after dispose is misuse")
end)

t:run()
