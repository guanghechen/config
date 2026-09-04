--- Run with: nvim -l lua/__test__/era/dressing/indentline/render.lua

local harness = require("__test__.harness")

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
    shiftwidth = 2,
    space = " ",
    breakindent = false,
    filetype = "lua",
    levels = { [0] = 2 },
    whitespace_lengths = { [0] = 4 },
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
    space = "·",
    levels = { [0] = 3 },
    whitespace_lengths = { [0] = 2 },
  })
  local virt_text = render.make_virt_text(value, 0, config)
  t.assert_eq("│·│ │ ", virt_text, "inherited guides")
end)

t:test("virt text follows horizontal scrolling", function()
  local value = frame({
    leftcol = 2,
    levels = { [0] = 3 },
    whitespace_lengths = { [0] = 6 },
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

t:run()
