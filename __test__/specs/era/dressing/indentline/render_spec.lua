--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/indentline/render_spec.lua

local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.indentline.render")
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

t:run()
