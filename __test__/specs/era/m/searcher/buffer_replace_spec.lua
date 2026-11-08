require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local Searcher = require("era.m.searcher.buffer")

---@class __test__.specs.era.m.searcher.buffer_replace.ISetup
---@field public searcher               era.m.searcher.buffer.Searcher
---@field public bufnr                  integer
---@field public search_pattern         stl.c.Observable
---@field public replace_pattern        stl.c.Observable
---@field public warnings               string[]

-- A searcher attached to a window that shows `lines`, with its matches found.
---@param lines                         string[]
---@param search_pattern                string
---@param replace_pattern               string
---@param flag_regex                    boolean
---@return __test__.specs.era.m.searcher.buffer_replace.ISetup
local function setup(lines, search_pattern, replace_pattern, flag_regex)
  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  local winnr = vim.api.nvim_open_win(bufnr, true, { split = "above" })

  local o_search_pattern = stl.c.Observable.from_value(search_pattern)
  local o_replace_pattern = stl.c.Observable.from_value(replace_pattern)
  local searcher = Searcher.new({
    o_flag_fuzzy = stl.c.Observable.from_value(false),
    o_flag_regex = stl.c.Observable.from_value(flag_regex),
    o_flag_replace = stl.c.Observable.from_value(true),
    o_flag_case_sensitive = stl.c.Observable.from_value(true),
    o_search_pattern = o_search_pattern,
    o_replace_pattern = o_replace_pattern,
  })
  t:defer(function()
    searcher:close()
    pcall(vim.api.nvim_win_close, winnr, true)
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end)

  local warnings = {} ---@type string[]
  t:patch_table(stl.reporter, "warn", function(value)
    warnings[#warnings + 1] = value.message
  end)
  t:patch_table(stl.reporter, "info", function() end)

  searcher:attach(winnr)
  t.wait_until(function()
    return searcher.o_match_total:snapshot() > 0
  end, 2000, "the search found no match")
  return {
    searcher = searcher,
    bufnr = bufnr,
    search_pattern = o_search_pattern,
    replace_pattern = o_replace_pattern,
    warnings = warnings,
  }
end

---@param bufnr                         integer
---@return string[]
local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
end

t:test("replacing changes what search lists in each line, never a line break", function()
  local s = setup({ "ab 1", "x", "ab 2" }, "a.*b", "#", true)
  s.searcher:replace_current_match()
  t.assert_same({ "# 1", "x", "ab 2" }, lines_of(s.bufnr), "the current match")
  s.searcher:replace_all_matches()
  t.assert_same({ "# 1", "x", "# 2" }, lines_of(s.bufnr), "all matches")

  s = setup({ "foo bar", "baz qux" }, [[\s+]], "_", true)
  s.searcher:replace_all_matches()
  t.assert_same({ "foo_bar", "baz_qux" }, lines_of(s.bufnr), "spaces without the line break")
end)

t:test("a replacement takes the groups of its match in the line", function()
  local s = setup({ "a=1 b=2", "xfoo" }, [[(\w)=(\d)]], "$2=$1", true)
  s.searcher:replace_all_matches()
  t.assert_same({ "1=a 2=b", "xfoo" }, lines_of(s.bufnr), "groups")

  s = setup({ "xfoo" }, [[\Bfoo]], "bar", true)
  s.searcher:replace_current_match()
  t.assert_same({ "xbar" }, lines_of(s.bufnr), "an assertion on the text before the match")

  s = setup({ "foo", "bar", "foo", "baz" }, "foo\nba(.)", "<$1>", true)
  s.searcher:replace_all_matches()
  t.assert_same({ "<r>", "<z>" }, lines_of(s.bufnr), "a pattern with a line break")
end)

t:test("replacing leaves the marks and signs of other lines where they are", function()
  local s = setup({ "foo 1", "x", "foo 2", "y", "z" }, "foo", "bar", false)
  local nsnr = vim.api.nvim_create_namespace("__test__.buffer_replace")
  vim.api.nvim_buf_set_mark(s.bufnr, "a", 4, 1, {})
  local extmark = vim.api.nvim_buf_set_extmark(s.bufnr, nsnr, 4, 0, { sign_text = "S" })

  s.searcher:replace_current_match()
  t.assert_same({ "bar 1", "x", "foo 2", "y", "z" }, lines_of(s.bufnr), "the current match")
  t.assert_same({ 4, 1 }, vim.api.nvim_buf_get_mark(s.bufnr, "a"), "the mark")
  t.assert_same({ 4, 0 }, vim.api.nvim_buf_get_extmark_by_id(s.bufnr, nsnr, extmark, {}), "the sign")

  s.searcher:replace_all_matches()
  t.assert_same({ "bar 1", "x", "bar 2", "y", "z" }, lines_of(s.bufnr), "all matches")
  t.assert_same({ 4, 1 }, vim.api.nvim_buf_get_mark(s.bufnr, "a"), "the mark after all")
  t.assert_same({ 4, 0 }, vim.api.nvim_buf_get_extmark_by_id(s.bufnr, nsnr, extmark, {}), "the sign after all")
end)

t:test("an edit after the search makes replacing find the matches again before it writes", function()
  local s = setup({ "foo 1", "foo 2" }, "foo", "bar", false)
  vim.api.nvim_buf_set_lines(s.bufnr, 0, 0, true, { "a new first line" })

  s.searcher:replace_current_match()
  t.assert_same({ "a new first line", "foo 1", "foo 2" }, lines_of(s.bufnr), "nothing written")
  t.assert_eq(1, #s.warnings, "says why")
  s.searcher:replace_current_match()
  t.assert_same({ "a new first line", "bar 1", "foo 2" }, lines_of(s.bufnr), "the match found again")

  vim.api.nvim_buf_set_lines(s.bufnr, -1, -1, true, { "foo 3" })
  s.searcher:replace_all_matches()
  t.assert_same({ "a new first line", "bar 1", "foo 2", "foo 3" }, lines_of(s.bufnr), "nothing written by all")
  s.searcher:replace_all_matches()
  t.assert_same({ "a new first line", "bar 1", "bar 2", "bar 3" }, lines_of(s.bufnr), "all found again")
end)

t:run()
