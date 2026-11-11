require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local Plainfile = require("era.m.searcher.view.plainfile")

local fixture_dir = t:tempdir()

-- Writes exact bytes; `writefile` would end every line with LF.
---@param name                          string
---@param text                          string
---@return string
local function fixture(name, text)
  local filepath = vim.fs.joinpath(fixture_dir, name)
  local file = assert(io.open(filepath, "wb"))
  file:write(text)
  file:close()
  return filepath
end

---@param filepath                      string
---@param search_pattern                string
---@param match_offsets                 integer[]
---@param flag_replace                  boolean
---@param filematch                     ?era.m.searcher.view.filetree.IResolvedFileMatch
---@return era.m.searcher.IPlainfileViewContext
local function context(filepath, search_pattern, match_offsets, flag_replace, filematch)
  local observable = stl.c.Observable.from_value
  return {
    flag_case_sensitive = observable(true),
    flag_regex = observable(false),
    flag_replace = observable(flag_replace),
    search_pattern = observable(search_pattern),
    replace_pattern = observable("bar"),
    filepath = filepath,
    filematch = filematch,
    offset_current = -1,
    match_offsets = match_offsets,
  }
end

---@param data                          era.m.searcher.IPlainfileViewData
---@return string[]
local function marks(data)
  local result = {} ---@type string[]
  for _, hl in ipairs(data.highlights) do
    result[#result + 1] = string.format("%s %d:%d-%d", hl.hlname, hl.lnum, hl.coll, hl.colr)
  end
  return result
end

local view = Plainfile.new({ name = "plainfile-line-breaks" })
t:defer(function()
  view:dispose()
end)
-- Each line holds "foo" at column 2; the copies differ only in their line breaks.
local lf = fixture("lf.txt", "a foo\nb foo\nc foo\n")
local crlf = fixture("crlf.txt", "a foo\r\nb foo\r\nc foo\r\n")

t:test("replace preview places CRLF matches on the rows and columns of the LF preview", function()
  local expected = view:calc_preview_data(context(lf, "foo", { 2, 8, 14 }, true))
  local actual = view:calc_preview_data(context(crlf, "foo", { 2, 9, 16 }, true))
  t.assert_same({ "a foobar", "b foobar", "c foobar" }, actual.lines, "preview lines")
  t.assert_same(marks(expected), marks(actual), "highlights of every match")

  actual = view:calc_preview_data(context(crlf, "foo", { 16 }, true))
  t.assert_same({ "m_sr_search 3:2-5", "m_sr_replace 3:5-8" }, marks(actual), "highlights of the last match")
end)

t:test("a match across a CRLF line break marks the line end and continues on the next row", function()
  local expected = view:calc_preview_data(context(lf, "foo\nb", { 2 }, true))
  local actual = view:calc_preview_data(context(crlf, "foo\r\nb", { 2 }, true))
  t.assert_same({ "a foo", "bbar foo", "c foo" }, actual.lines, "preview lines")
  t.assert_same({ "m_sr_search 1:2-6", "m_sr_search 2:0-1", "m_sr_replace 2:1-4" }, marks(actual), "highlights")
  t.assert_same(marks(expected), marks(actual), "LF highlights")
end)

t:test("ranges past the last line stop at the last row", function()
  t:patch_table(yoz.replace, "replace_file_preview_by_matches_advance", function()
    return { text = "a foo\r\n", matches = { { l = 2, r = 5 }, { l = 5, r = 40 } } }, nil
  end)
  local data = view:calc_preview_data(context(crlf, "foo", { 2 }, true))
  t.assert_same({ "m_sr_search 1:2-5", "m_sr_replace 1:5-6" }, marks(data), "highlights clipped to the text")

  t:patch_table(yoz.replace, "replace_file_preview_by_matches_advance", function()
    return { text = "", matches = { { l = 0, r = 3 }, { l = 3, r = 6 } } }, nil
  end)
  data = view:calc_preview_data(context(crlf, "foo", { 0 }, true))
  t.assert_same({}, marks(data), "an empty preview has no rows to mark")
end)

t:test("search preview drops the carriage return of CRLF line breaks", function()
  ---@type era.m.searcher.view.filetree.IResolvedFileMatch
  local filematch = {
    filepath = crlf,
    relative = "crlf.txt",
    matches = { { lx = 2, ly = 2, cx = 2, cy = 4, ox = 9, oy = 11, s = "b foo", sx = 2, sy = 4 } },
  }
  local data = view:calc_preview_data(context(crlf, "foo", { 9 }, false, filematch))
  t.assert_same({ "a foo", "b foo", "c foo" }, data.lines, "preview lines")
  t.assert_same({ "m_sr_match 2:2-5" }, marks(data), "highlight of the match")
end)

t:test("a replace preview that cannot be made shows the matches as search does", function()
  local errors = 0 ---@type integer
  t:patch_table(stl.reporter, "error", function()
    errors = errors + 1
  end)

  -- A file that is not UTF-8 text: "foo" starts at column 7 of the second line, after the byte 0xE9.
  local latin1 = fixture("latin1.txt", "a foo\r\nb caf\233 foo\r\n")
  ---@type era.m.searcher.view.filetree.IResolvedFileMatch
  local filematch = {
    filepath = latin1,
    relative = "latin1.txt",
    matches = { { lx = 2, ly = 2, cx = 7, cy = 9, ox = 14, oy = 16, s = "b caf\u{FFFD} foo", sx = 9, sy = 11 } },
  }
  local current = context(latin1, "foo", { 14 }, true, filematch)
  current.offset_current = 14
  local data = view:calc_preview_data(current)
  t.assert_same({ "a foo", "b caf\233 foo" }, data.lines, "the lines of the file")
  t.assert_same({ "m_sr_match 2:7-10" }, marks(data), "the match as search marks it")
  t.assert_same({ "m_sr_match_cur 2:7-10" }, marks({ highlights = view:patch_preview_data(current, data) }), "current")

  -- A pattern that matches bytes outside UTF-8: the two bytes of "é".
  local accent = fixture("accent.txt", "café foo\n")
  filematch = {
    filepath = accent,
    relative = "accent.txt",
    matches = { { lx = 1, ly = 1, cx = 3, cy = 4, ox = 3, oy = 4, s = "café foo", sx = 3, sy = 3 } },
  }
  current = context(accent, [[(?-u:\xC3\xA9)]], { 3 }, true, filematch)
  current.flag_regex = stl.c.Observable.from_value(true)
  data = view:calc_preview_data(current)
  t.assert_same({ "café foo" }, data.lines, "the lines of the file")
  t.assert_same({ "m_sr_match 1:3-5" }, marks(data), "the bytes as search marks them")
  t.assert_eq(0, errors, "nothing to report while drawing")
end)

t:test("rendering a CRLF replace preview writes clean lines and marks each row of the match", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  view:render(context(crlf, "foo\r\nb", { 2 }, true), bufnr, crlf, true)
  t.assert_same({ "a foo", "bbar foo", "c foo" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, true), "buffer lines")

  local starts = {} ---@type string[]
  for _, extmark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, dot.var.nsnr.searcher_searched, 0, -1, {})) do
    starts[#starts + 1] = string.format("%d:%d", extmark[2], extmark[3])
  end
  t.assert_same({ "0:2", "1:0", "1:1" }, starts, "highlight starts")
end)

t:run()
