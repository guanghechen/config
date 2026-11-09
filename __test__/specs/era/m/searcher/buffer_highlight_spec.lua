require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local Searcher = require("era.m.searcher.buffer")

local NSNR_SEARCH = vim.api.nvim_get_namespaces()["era.m.searcher.buffer"] ---@type integer
local NSNR_SEARCH_CURRENT = vim.api.nvim_get_namespaces()["era.m.searcher.buffer.current"] ---@type integer

-- A buffer of `lines` in a window, with the matches of `pattern` found.
---@param lines                         string[]
---@param pattern                       string
---@return integer
local function search(lines, pattern)
  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  local winnr = vim.api.nvim_open_win(bufnr, true, { split = "above" })
  local searcher = Searcher.new({
    o_flag_fuzzy = stl.c.Observable.from_value(false),
    o_flag_regex = stl.c.Observable.from_value(false),
    o_flag_replace = stl.c.Observable.from_value(false),
    o_flag_case_sensitive = stl.c.Observable.from_value(true),
    o_search_pattern = stl.c.Observable.from_value(pattern),
    o_replace_pattern = stl.c.Observable.from_value(""),
  })
  t:defer(function()
    searcher:close()
    pcall(vim.api.nvim_win_close, winnr, true)
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end)
  searcher:attach(winnr)
  t.wait_until(function()
    return searcher.o_match_total:snapshot() > 0
  end, 2000, "the search found no match")
  return bufnr
end

-- "row:col-row:col hl" for each mark of the namespace.
---@param bufnr                         integer
---@param nsnr                          integer
---@return string[]
local function marks(bufnr, nsnr)
  local result = {} ---@type string[]
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, nsnr, 0, -1, { details = true })) do
    local details = mark[4]
    result[#result + 1] =
      string.format("%d:%d-%d:%d %s", mark[2], mark[3], details.end_row, details.end_col, details.hl_group)
  end
  return result
end

t:test("the search marks the bytes of every match and the current match again", function()
  local bufnr = search({ "foo café", "x", "café foo" }, "café")
  t.assert_same({ "0:4-0:9 Search", "2:0-2:5 Search" }, marks(bufnr, NSNR_SEARCH), "every match")
  t.assert_same({ "0:4-0:9 IncSearch" }, marks(bufnr, NSNR_SEARCH_CURRENT), "the current match")
end)

t:test("a match across lines is marked on each of its lines", function()
  local bufnr = search({ "ab", "", "cd" }, "b\n\nc")
  t.assert_same({ "0:1-0:2 Search", "1:0-1:0 Search", "2:0-2:1 Search" }, marks(bufnr, NSNR_SEARCH), "every line")
end)

t:run()
