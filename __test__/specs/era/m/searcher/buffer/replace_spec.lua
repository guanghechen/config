require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
local picker = require("__test__.support.picker")
-- Loading the searcher creates the namespace of its replace previews.
require("era.m.searcher.buffer")

---@class __test__.specs.era.m.searcher.buffer.replace.ISetup
---@field public searcher               era.m.searcher.buffer.Searcher
---@field public bufnr                  integer
---@field public search_pattern         stl.c.Observable
---@field public replace_pattern        stl.c.Observable
---@field public warnings               table[] The warnings reported since the setup.

-- A searcher attached to a window that shows `lines`, with its matches found.
---@param lines                         string[]
---@param search_pattern                string
---@param replace_pattern               string
---@param flag_regex                    boolean
---@return __test__.specs.era.m.searcher.buffer.replace.ISetup
local function setup(lines, search_pattern, replace_pattern, flag_regex)
  local reports = bootstrap.with_reporter(t)
  local o_search_pattern = picker.observable(search_pattern)
  local o_replace_pattern = picker.observable(replace_pattern)
  local searcher, bufnr = picker.buffer_searcher(t, lines, {
    o_flag_regex = flag_regex,
    o_flag_replace = true,
    o_search_pattern = o_search_pattern,
    o_replace_pattern = o_replace_pattern,
  })
  return {
    searcher = searcher,
    bufnr = bufnr,
    search_pattern = o_search_pattern,
    replace_pattern = o_replace_pattern,
    warnings = reports.warn,
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

local NSNR_PREVIEW = vim.api.nvim_get_namespaces()["era.m.searcher.buffer.replace_preview"] ---@type integer

-- The preview marks: "row:col-row:col hl" for the struck text, "row:col text hl" for the replacement after it.
---@param bufnr                         integer
---@return string[]
---@return integer[]
local function previews(bufnr)
  local result, ids = {}, {} ---@type string[], integer[]
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, NSNR_PREVIEW, 0, -1, { details = true })) do
    local details = mark[4]
    ids[#ids + 1] = mark[1]
    if details.virt_text ~= nil then
      result[#result + 1] =
        string.format("%d:%d %s %s", mark[2], mark[3], details.virt_text[1][1], details.virt_text[1][2])
    else
      result[#result + 1] =
        string.format("%d:%d-%d:%d %s", mark[2], mark[3], details.end_row, details.end_col, details.hl_group)
    end
  end
  return result, ids
end

t:test("the preview strikes each match and adds its replacement, and moving restyles two of them in place", function()
  local s = setup({ "foo 1", "x foo", "foo", "bar" }, "foo", "qux", false)
  local marks, ids = previews(s.bufnr)
  t.assert_same({
    "0:0-0:3 m_sr_search_cur",
    "0:3 qux m_sr_replace_cur",
    "1:2-1:5 m_sr_search",
    "1:5 qux m_sr_replace",
    "2:0-2:3 m_sr_search",
    "2:3 qux m_sr_replace",
  }, marks, "the first match is the current one")

  local writes = 0 ---@type integer
  local set_extmark = vim.api.nvim_buf_set_extmark
  t:patch_table(vim.api, "nvim_buf_set_extmark", function(bufnr, nsnr, ...)
    if nsnr == NSNR_PREVIEW then
      writes = writes + 1
    end
    return set_extmark(bufnr, nsnr, ...)
  end)
  s.searcher:goto_next_match()
  vim.wait(20)
  t.assert_eq(4, writes, "only the marks of the two matches change")
  local moved, moved_ids = previews(s.bufnr)
  t.assert_same({
    "0:0-0:3 m_sr_search",
    "0:3 qux m_sr_replace",
    "1:2-1:5 m_sr_search_cur",
    "1:5 qux m_sr_replace_cur",
    "2:0-2:3 m_sr_search",
    "2:3 qux m_sr_replace",
  }, moved, "the second match is the current one")
  t.assert_same(ids, moved_ids, "the same marks")

  s = setup({ "foo", "bar baz" }, "foo\nbar", "X", false)
  t.assert_same({ "0:0-1:3 m_sr_search_cur", "1:3 X m_sr_replace_cur" }, previews(s.bufnr), "across a line break")
end)

t:test("a replacement edit after an edit of the buffer previews the matches found again", function()
  local s = setup({ "foo 1", "foo 2" }, "foo", "qux", false)
  vim.api.nvim_buf_set_lines(s.bufnr, 0, 0, true, { "foo 0" })
  s.replace_pattern:next("quux")
  t.wait_until(function()
    return #previews(s.bufnr) == 6
  end, 5000, "the preview of the three matches")
  t.assert_same({
    "0:0-0:3 m_sr_search_cur",
    "0:3 quux m_sr_replace_cur",
    "1:0-1:3 m_sr_search",
    "1:3 quux m_sr_replace",
    "2:0-2:3 m_sr_search",
    "2:3 quux m_sr_replace",
  }, previews(s.bufnr), "every match where it is now")
end)

t:run()
