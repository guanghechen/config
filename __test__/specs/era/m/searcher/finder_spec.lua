local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local picker = require("__test__.support.picker")

t:test("Finder renders a highlighted title accent without changing its plain-title contract", function()
  local input = picker.observable("")
  t:defer(function()
    input:dispose()
  end)
  local finder = era.m.searcher.Finder.new({
    name = "finder-title-accent",
    keymaps = {},
    input = input,
    title = "Search Files",
  })
  t:defer(function()
    finder:dispose()
  end)
  local winnr = finder:create_win({
    border = "single",
    winhighlight = "",
  }, {
    row = 0,
    col = 0,
    width = 40,
    height = 1,
  })

  finder:set_title("Search Files", {
    text = "⡀",
    hl = "m_pk_search_spinner_aqua",
  })
  local title = vim.api.nvim_win_get_config(winnr).title
  t.assert_eq(" ⡀ Search Files ", finder.title)
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(" ⡀", title[1][1])
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("m_pk_search_spinner_aqua", title[1][2])
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(" Search Files ", title[2][1])
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(nil, title[2][2], "title text must retain the window's FloatTitle highlight")

  finder:set_title("Search Files")
  title = vim.api.nvim_win_get_config(winnr).title
  t.assert_eq(" Search Files ", finder._title_render)
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(" Search Files ", title[1][1])
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(nil, title[1][2])
end)

t:run()
