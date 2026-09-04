--- Run with: nvim -l lua/__test__/era/dressing/indentline/render.lua

local harness = require("__test__.harness")

local t = harness.new("era.dressing.indentline.render")
local parser = require("era.dressing.indentline.parser")
local render = require("era.dressing.indentline.render")

local config = {
  char = "│",
  priority = 1,
  highlights = { "h1", "h2", "h3" },
} ---@type era.dressing.indentline.IConfig

---@param props                         table|nil
---@return era.dressing.indentline.render.IFrame
local function frame(props)
  return vim.tbl_extend("force", {
    bufnr = 1,
    changedtick = 1,
    start_row = 0,
    end_row = 1,
    leftcol = 0,
    is_current = true,
    indent_options = {
      shiftwidth = 2,
      tabstop = 2,
      vartabstops = {},
    },
    whitespace_style = {
      space = " ",
      blank_space = " ",
      tab_start = ">",
      tab_fill = "-",
    },
    breakindent = false,
    filetype = "lua",
    levels = { [0] = 2 },
    blank_rows = {},
    tab_whitespaces = {},
    whitespace_widths = { [0] = 4 },
    row_virt_texts = {},
    blank_virt_texts = {},
    plain_virt_texts = {},
    virt_texts = {},
  }, props or {})
end

t:test("virt text preserves upstream guide and rainbow semantics", function()
  local virt_text, hlgroup = render.make_virt_text(frame(nil), 0, config)
  t.assert_eq("│ │ ", virt_text, "guides")
  t.assert_eq("h3", hlgroup, "rainbow group")
end)

t:test("virt text distinguishes inherited indent from real listchars whitespace", function()
  local value = frame({
    whitespace_style = {
      space = "·",
      blank_space = " ",
      tab_start = ">",
      tab_fill = "-",
    },
    levels = { [0] = 3 },
    tab_whitespaces = {},
    whitespace_widths = { [0] = 2 },
  })
  local virt_text = render.make_virt_text(value, 0, config)
  t.assert_eq("│·│ │ ", virt_text, "inherited guides")
end)

t:test("virt text preserves listchars spacing patterns", function()
  local leading = frame({
    whitespace_style = {
      space = "·",
      multispace = { "a", "b" },
      blank_space = "x",
      tab_start = ">",
      tab_fill = "-",
    },
  })
  t.assert_eq("│b│b", render.make_virt_text(leading, 0, config), "leading multispace")

  local blank = frame({
    whitespace_style = {
      space = "·",
      blank_space = "x",
      tab_start = ">",
      tab_fill = "-",
    },
    blank_rows = { [0] = true },
  })
  t.assert_eq("│x│x", render.make_virt_text(blank, 0, config), "blank trail")
end)

t:test("virt text expands tabs by visual columns and preserves tab fill", function()
  local value = frame({
    indent_options = {
      shiftwidth = 2,
      tabstop = 8,
      vartabstops = {},
    },
    levels = { [0] = 4 },
    tab_whitespaces = { [0] = "\t" },
    whitespace_widths = { [0] = 8 },
  })
  local virt_text = render.make_virt_text(value, 0, config)
  t.assert_eq("│-│-│-│-", virt_text, "tab guides")
end)

t:test("virt text supports shiftwidth one", function()
  local value = frame({
    indent_options = {
      shiftwidth = 1,
      tabstop = 8,
      vartabstops = {},
    },
    levels = { [0] = 2 },
    tab_whitespaces = {},
    whitespace_widths = { [0] = 2 },
  })
  local virt_text = render.make_virt_text(value, 0, config)
  t.assert_eq("││", virt_text, "one-column guides")
end)

t:test("virt text preserves native tabs when listchars.tab is absent", function()
  local value = frame({
    whitespace_style = {
      space = "·",
      blank_space = " ",
    },
    indent_options = {
      shiftwidth = 2,
      tabstop = 8,
      vartabstops = {},
    },
    levels = { [0] = 4 },
    tab_whitespaces = { [0] = "\t" },
    whitespace_widths = { [0] = 8 },
  })
  local virt_text, hlgroup = render.make_virt_text(value, 0, config)
  t.assert_eq(nil, virt_text, "native tab row")
  t.assert_eq(nil, hlgroup, "native tab highlight")
  t.assert_eq(false, value.row_virt_texts[0], "native tab cache")
end)

t:test("virt text follows horizontal scrolling", function()
  local value = frame({
    leftcol = 2,
    levels = { [0] = 3 },
    tab_whitespaces = {},
    whitespace_widths = { [0] = 6 },
  })
  local virt_text = render.make_virt_text(value, 0, config)
  t.assert_eq("│ │ ", virt_text, "scrolled guides")
end)

t:test("frame cache is window-local and invalidated by changedtick", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "  one", "", "    two" })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })

  local ok, err = pcall(function()
    render.invalidate()
    local first = render.build_frame(winnr, bufnr, 0, 3)
    local second = render.build_frame(winnr, bufnr, 0, 3)
    t.assert_true(first ~= nil, "first frame")
    t.assert_true(rawequal(first, second), "cached frame")
    t.assert_eq(2, first and first.levels[1], "blank inherited indent")

    vim.api.nvim_buf_set_lines(bufnr, 2, 3, false, { "      changed" })
    local changed = render.build_frame(winnr, bufnr, 0, 3)
    t.assert_false(rawequal(first, changed), "changed frame")
    t.assert_true(rawequal(first and first.indent_options, changed and changed.indent_options), "reused indent options")
    t.assert_true(
      rawequal(first and first.whitespace_style, changed and changed.whitespace_style),
      "reused whitespace style"
    )
    t.assert_eq(3, changed and changed.levels[2], "changed indent")
  end)

  render.invalidate()
  if vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end)

t:test("horizontal projection reuses unchanged parsed content", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local previous_wrap = vim.api.nvim_get_option_value("wrap", { win = winnr }) ---@type boolean
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { string.rep(" ", 100) .. string.rep("x", 200) })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })
  vim.api.nvim_set_option_value("wrap", false, { win = winnr })

  local parse_calls = 0 ---@type integer
  local original_parse = parser.parse
  local restore = t:patch_table(parser, "parse", function(...)
    parse_calls = parse_calls + 1
    return original_parse(...)
  end)
  local ok, err = pcall(function()
    render.invalidate()
    local first, first_redraw = render.build_frame(winnr, bufnr, 0, 1)
    vim.api.nvim_win_call(winnr, function()
      vim.api.nvim_win_set_cursor(winnr, { 1, 100 })
      vim.cmd("normal! 20zl")
    end)
    local second, second_redraw = render.build_frame(winnr, bufnr, 0, 1)

    t.assert_true(first_redraw, "first projection")
    t.assert_true(second_redraw, "changed projection")
    t.assert_true(rawequal(first, second), "shared content frame")
    t.assert_true(second ~= nil and second.leftcol > 0, "horizontal offset")
    t.assert_eq(1, parse_calls, "content parse count")
  end)

  restore()
  render.invalidate()
  if vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_option_value("wrap", previous_wrap, { win = winnr })
  end
  if vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end)

t:test("frame resolves blank indentation beyond viewport boundaries", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  local lines = { "      deep" } ---@type string[]
  for index = 2, 21 do
    lines[index] = ""
  end
  lines[22] = "  shallow"
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "text", { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })

  local ok, err = pcall(function()
    render.invalidate()
    local without_boundary = render.build_frame(winnr, bufnr, 10, 20)
    local with_following_boundary = render.build_frame(winnr, bufnr, 10, 21)
    t.assert_eq(3, without_boundary and without_boundary.levels[10], "blank without visible boundary")
    t.assert_eq(3, with_following_boundary and with_following_boundary.levels[10], "blank with following boundary")
  end)

  render.invalidate()
  if vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end)

t:run()
