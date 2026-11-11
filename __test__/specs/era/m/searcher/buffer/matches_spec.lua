require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local picker = require("__test__.support.picker")
-- Loading the searcher creates the namespaces below.
require("era.m.searcher.buffer")

local NSNR_SEARCH = vim.api.nvim_get_namespaces()["era.m.searcher.buffer"] ---@type integer
local NSNR_SEARCH_CURRENT = vim.api.nvim_get_namespaces()["era.m.searcher.buffer.current"] ---@type integer

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
  local _, bufnr = picker.buffer_searcher(t, { "foo café", "x", "café foo" }, { o_search_pattern = "café" })
  t.assert_same({ "0:4-0:9 Search", "2:0-2:5 Search" }, marks(bufnr, NSNR_SEARCH), "every match")
  t.assert_same({ "0:4-0:9 IncSearch" }, marks(bufnr, NSNR_SEARCH_CURRENT), "the current match")
end)

t:test("a match across lines is marked on each of its lines", function()
  local _, bufnr = picker.buffer_searcher(t, { "ab", "", "cd" }, { o_search_pattern = "b\n\nc" })
  t.assert_same({ "0:1-0:2 Search", "1:0-1:0 Search", "2:0-2:1 Search" }, marks(bufnr, NSNR_SEARCH), "every line")
end)

t:run()
