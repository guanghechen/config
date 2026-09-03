---@diagnostic disable: undefined-global

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.ui_attach.popupmenu")

bootstrap.with_stl(t, {
  string = {
    pad_end = function(text, width, pad)
      return text .. string.rep(pad, math.max(0, width - vim.api.nvim_strwidth(text)))
    end,
  },
})

---@return era.m.ui_attach.popupmenu
---@return era.m.ui_attach.state
local function setup()
  t:patch_global("dot", {
    var = {
      CMP_DOCUMENTATION_PREVIEW = "<preview>",
      CMP_DOCUMENTATION_SEPARATOR = "<separator>",
      N_CMP_DOCUMENTATION = "dot_cmp_documentation",
      nsnr = { popupmenu = 1, popupmenu_selected = 2 },
      zindex = { POPUPMENU = 100 },
    },
  })
  t:patch_table(vim, "g", { ui_cmdline_pos = { 4, 10 } })

  local states = require("era.m.ui_attach.state")
  t:patch_table(states, "cmdline", {
    [1] = {
      level = 1,
      first = "edit ",
      second = "文件",
    },
  })

  ---@diagnostic disable-next-line: redundant-return-value
  return assert(loadfile("lua/era/m/ui_attach/popupmenu.lua"))(), states
end

t:test("external cmdline popup applies byte column as display width", function()
  local popupmenu = setup()

  local row, col = popupmenu._resolve_position({
    items = {},
    selected = -1,
    row = 0,
    col = 8,
    grid = -1,
  })

  t.assert_eq(3, row, "popup row")
  t.assert_eq(17, col, "popup column")
end)

t:test("selection scrolls the popup window to the selected item", function()
  local popupmenu, states = setup()
  states.popupmenu = {
    owner = "native",
    generation = 1,
    items = { { "a" }, { "b" }, { "abc", "", "", "", "", "", { { 0, 1, "PmenuMatch", 150 } } } },
    selected = -1,
    row = 0,
    col = 0,
    grid = 1,
    bufnr = 1,
    winnr = 2,
    label_geometry = { [3] = { start_col = 1, visible_bytes = 3 } },
  }
  local cursor = nil
  local selection = nil
  local selected_match = nil
  local redraws = 0
  t:patch_table(vim.api, "nvim_buf_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_buf_clear_namespace", function() end)
  t:patch_table(vim.api, "nvim_buf_get_lines", function()
    return { " abc " }
  end)
  t:patch_table(vim.api, "nvim_buf_set_extmark", function(_, nsnr, row, col, opts)
    if nsnr == 2 then
      if opts.hl_group == "PmenuSel" then
        selection = { row = row, col = col, opts = opts }
      elseif opts.hl_group == "PmenuMatchSel" then
        selected_match = { row = row, col = col, opts = opts }
      end
    end
    return 1
  end)
  t:patch_table(vim.api, "nvim_win_set_cursor", function(_, value)
    cursor = value
  end)
  t:patch_table(vim.api, "nvim__redraw", function()
    redraws = redraws + 1
  end)

  popupmenu.select({ event = "popupmenu_select", args = { 2 } })

  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(3, cursor[1], "selected cursor row")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(0, cursor[2], "selected cursor column")
  t.assert_eq(2, selection.row, "selection row")
  t.assert_eq("PmenuSel", selection.opts.hl_group, "selection highlight")
  t.assert_eq("combine", selection.opts.hl_mode, "selection composition")
  t.assert_eq(50, selection.opts.priority, "selection priority")
  t.assert_eq(2, selected_match.row, "selected match row")
  t.assert_eq(1, selected_match.col, "selected match column")
  t.assert_eq("PmenuMatchSel", selected_match.opts.hl_group, "selected match highlight")
  t.assert_eq("combine", selected_match.opts.hl_mode, "selected match composition")
  t.assert_eq(1, redraws, "immediate redraw")

  popupmenu.select_owned("native", 1, 1, false)
  t.assert_eq(1, redraws, "deferred redraw")
end)

t:test("native events cannot replace or dismiss an owned popup", function()
  local popupmenu, states = setup()
  states.popupmenu = {
    owner = "era-cmp-insert",
    generation = 7,
    items = { { "owned" } },
    selected = 0,
    row = 0,
    col = 0,
    grid = 1,
  }

  popupmenu.show({ event = "popupmenu_show", args = { { { "native" } }, 0, 1, 1, 1 } })
  popupmenu.hide({ event = "popupmenu_hide", args = {} })

  t.assert_eq("era-cmp-insert", states.popupmenu.owner, "owner")
  t.assert_eq("owned", states.popupmenu.items[1][1], "items")
end)

t:test("stale owned actions cannot mutate a newer generation", function()
  local popupmenu, states = setup()
  states.popupmenu = {
    owner = "era-cmp-insert",
    generation = 8,
    items = { { "owned" } },
    selected = 0,
    row = 0,
    col = 0,
    grid = 1,
  }

  t.assert_false(popupmenu.select_owned("era-cmp-insert", 7, -1), "stale select")
  t.assert_false(popupmenu.dismiss("era-cmp-insert", 7), "stale dismiss")
  t.assert_eq(0, states.popupmenu.selected, "selection")
end)

t:test("popup prefers below and never occupies the anchor row", function()
  local popupmenu = setup()
  local layout = assert(popupmenu._resolve_layout(5, 20, 20, 30, 4, 40, 80, 10))

  t.assert_eq("s", layout.direction, "direction")
  t.assert_eq(6, layout.row, "row below anchor")
  t.assert_eq(10, layout.height, "pumheight")
  t.assert_eq(15, layout.col, "label alignment")
end)

t:test("popup moves above when the lower edge is constrained", function()
  local popupmenu = setup()
  local layout = assert(popupmenu._resolve_layout(22, 20, 20, 30, 4, 24, 80, 10))

  t.assert_eq("n", layout.direction, "direction")
  t.assert_eq(10, layout.row, "row above anchor")
  t.assert_eq(10, layout.height, "height")
  t.assert_true(layout.row + layout.height + 1 < 22, "border stays above anchor")
end)

t:test("popup respects the active window screen bounds", function()
  local popupmenu = setup()
  local layout = assert(popupmenu._resolve_layout(21, 3, 1, 20, 1, 23, 80, 10, 1))

  t.assert_eq("n", layout.direction, "direction")
  t.assert_eq(18, layout.row, "row above statusline")
end)

t:test("popup and documentation stay inside active split columns", function()
  local popupmenu = setup()
  local first_col = 40
  local last_col = 70
  local menu = assert(popupmenu._resolve_layout(10, 65, 10, 80, 3, 30, last_col, 10, 0, first_col))

  t.assert_true(menu.col >= first_col, "menu left edge")
  t.assert_true(menu.col + menu.width + 2 <= last_col, "menu right edge")

  local docs = assert(popupmenu._resolve_documentation_layout(menu, 60, 8, 30, last_col, 0, first_col))
  t.assert_true(docs.col >= first_col, "documentation left edge")
  t.assert_true(docs.col + docs.width + 2 <= last_col, "documentation right edge")
end)

t:test("external cmdline row is converted before constrained layout", function()
  local popupmenu = setup()
  local row, col = popupmenu._resolve_position({
    items = {},
    selected = -1,
    row = 0,
    col = 8,
    grid = -1,
  })
  local layout = assert(popupmenu._resolve_layout(row, col, 4, 20, 3, 8, 80, 10))

  t.assert_eq(3, row, "zero-based anchor")
  t.assert_eq("s", layout.direction, "direction")
  t.assert_true(layout.row > row, "popup stays below input")
end)

t:test("popup keeps documentation out of menu rows", function()
  local popupmenu = setup()
  local lines, width, label_offset, highlights =
    popupmenu._format_items({ { "candidate", "K", "[buffer]", "long docs" } })

  t.assert_eq(" K candidate [buffer] ", lines[1], "menu columns")
  t.assert_false(lines[1]:find("long docs", 1, true) ~= nil, "documentation")
  t.assert_eq(22, width, "content width")
  t.assert_eq(3, label_offset, "label offset")
  t.assert_eq("Function", highlights[1].group, "kind highlight")
  t.assert_eq("NonText", highlights[2].group, "source highlight")
end)

t:test("popup aligns source names in one column", function()
  local popupmenu = setup()
  local lines = popupmenu._format_items({
    { "a", "K", "[path]" },
    { "long", "K", "[snippets]" },
  })

  t.assert_eq(" K a    [path]     ", lines[1], "short source row")
  t.assert_eq(" K long [snippets] ", lines[2], "long source row")
  t.assert_eq(assert(lines[1]:find("%[")), assert(lines[2]:find("%[")), "source start column")
end)

t:test("popup accepts a semantic source highlight", function()
  local popupmenu = setup()
  local _, _, _, highlights = popupmenu._format_items({ { "edit", "K", "[cmd]", "", "", "Function", {}, "Keyword" } })

  t.assert_eq("Function", highlights[1].group, "kind highlight")
  t.assert_eq("Keyword", highlights[2].group, "source highlight")
end)

t:test("popup renders label descriptions with lower visual weight", function()
  local popupmenu = setup()
  local lines, width, _, highlights =
    popupmenu._format_items({ { "probeItem()", "F", "[lsp]", "", "from-demo-server", "Function" } })

  t.assert_eq(" F probeItem() from-demo-server [lsp] ", lines[1], "description column")
  t.assert_eq(38, width, "description width")
  t.assert_eq("Function", highlights[1].group, "kind highlight")
  t.assert_eq("Comment", highlights[2].group, "description highlight")
  t.assert_eq("NonText", highlights[3].group, "source highlight")
end)

t:test("long descriptions yield space to a complete label", function()
  local popupmenu = setup()
  local label = "very_long_completion_label"
  local lines = popupmenu._format_items({
    { label, "F", "[lsp]", "", string.rep("module.", 12), "Function" },
  }, 80)

  t.assert_eq(80, vim.api.nvim_strwidth(lines[1]), "fitted width")
  t.assert_true(lines[1]:find(label, 1, true) ~= nil, "complete label")
  t.assert_true(lines[1]:find("…", 1, true) ~= nil, "truncated description")
  t.assert_true(lines[1]:find("[lsp]", 1, true) ~= nil, "source")
end)

t:test("popup scrollbar tracks an overflowing viewport", function()
  local popupmenu = setup()

  t.assert_nil(popupmenu._resolve_scrollbar(10, 10, 1), "fully visible list")
  local first = assert(popupmenu._resolve_scrollbar(20, 10, 1))
  local last = assert(popupmenu._resolve_scrollbar(20, 10, 11))
  t.assert_eq(0, first.row, "first viewport row")
  t.assert_eq(4, first.height, "thumb height")
  t.assert_eq(6, last.row, "last viewport row")
  t.assert_eq(4, last.height, "stable thumb height")
end)

t:test("narrow popup preserves a Unicode label before its source", function()
  local popupmenu = setup()
  local lines, width, _, highlights = popupmenu._format_items({ { "候选candidate", "λ", "[long-source]" } }, 15)

  t.assert_eq(15, vim.api.nvim_strwidth(lines[1]), "fitted width")
  t.assert_eq(31, width, "desired width")
  t.assert_true(lines[1]:find("候选", 1, true) ~= nil, "label prefix")
  t.assert_true(lines[1]:find("…", 1, true) ~= nil, "label truncation")
  t.assert_false(lines[1]:find("long-source", 1, true) ~= nil, "hidden source")
  t.assert_eq(1, #highlights, "visible field highlights")
end)

t:test("popup offsets label highlights and clips them before the ellipsis", function()
  local popupmenu = setup()
  local lines, _, _, highlights = popupmenu._format_items({
    { "abcdef", "", "", "", "", "", { { 0, 2, "@variable.lua", 100 }, { 2, 5, "PmenuMatch", 150 } } },
  }, 6)

  t.assert_eq(" abc… ", lines[1], "truncated label")
  t.assert_true(
    vim.deep_equal({ row = 0, start_col = 1, end_col = 3, group = "@variable.lua", priority = 100 }, highlights[1]),
    "semantic range"
  )
  t.assert_true(
    vim.deep_equal({ row = 0, start_col = 3, end_col = 4, group = "PmenuMatch", priority = 150 }, highlights[2]),
    "clipped match"
  )
end)

t:test("popup resolves semantic highlights only for newly visible rows", function()
  local popupmenu, states = setup()
  local resolve_calls = 0
  local rendered = {}
  states.popupmenu = {
    owner = "era-cmp-insert",
    generation = 1,
    items = { { "one", "", "", "" }, { "two", "", "", "" }, { "three", "", "", "" } },
    selected = 0,
    row = 0,
    col = 0,
    grid = 1,
    bufnr = 1,
    winnr = 2,
    label_geometry = {
      { start_col = 1, visible_bytes = 3 },
      { start_col = 1, visible_bytes = 3 },
      { start_col = 1, visible_bytes = 5 },
    },
    resolve_highlights = function(indices)
      resolve_calls = resolve_calls + 1
      t.assert_true(vim.deep_equal({ 2, 3 }, indices), "visible indices")
      return {
        [2] = { { 0, 3, "@variable.lua", 100 } },
        [3] = { { 0, 5, "@function.lua", 100 } },
      }
    end,
  }
  t:patch_table(vim.api, "nvim_buf_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_buf_clear_namespace", function() end)
  t:patch_table(vim.api, "nvim_win_set_cursor", function() end)
  t:patch_table(vim.api, "nvim__redraw", function() end)
  t:patch_table(vim.fn, "line", function(value)
    return value == "w0" and 2 or 3
  end)
  t:patch_table(vim.api, "nvim_buf_set_extmark", function(_, nsnr, row, col, opts)
    if nsnr == 1 then
      rendered[#rendered + 1] = { opts.hl_group, { row, col }, { row, opts.end_col }, opts.priority, opts.hl_mode }
    end
    return 1
  end)

  popupmenu.select_owned("era-cmp-insert", 1, 1)
  popupmenu.select_owned("era-cmp-insert", 1, 2)

  t.assert_eq(1, resolve_calls, "resolver calls")
  t.assert_eq(2, #rendered, "semantic extmarks")
  t.assert_true(vim.deep_equal({ "@variable.lua", { 1, 1 }, { 1, 4 }, 100, "combine" }, rendered[1]), "second row")
  t.assert_true(vim.deep_equal({ "@function.lua", { 2, 1 }, { 2, 6 }, 100, "combine" }, rendered[2]), "third row")
end)

t:test("side documentation shares the adjacent menu border", function()
  local popupmenu = setup()
  local right =
    assert(popupmenu._resolve_documentation_layout({ row = 5, col = 10, width = 20, height = 5 }, 30, 8, 40, 100))
  t.assert_eq(31, right.col, "shared right border")
  t.assert_eq(30, right.width, "right width")

  local left =
    assert(popupmenu._resolve_documentation_layout({ row = 5, col = 50, width = 20, height = 5 }, 40, 8, 40, 75))
  t.assert_eq(9, left.col, "shared left border")
  t.assert_eq(40, left.width, "left width")
end)

t:test("north side documentation stays above the input row", function()
  local popupmenu = setup()
  local layout = assert(
    popupmenu._resolve_documentation_layout(
      { row = 10, col = 10, width = 20, height = 10, direction = "n" },
      30,
      12,
      40,
      100
    )
  )

  local anchor_row = 22
  t.assert_eq(10, layout.height, "north menu height")
  t.assert_true(layout.row + layout.height + 1 < anchor_row, "border stays above input")
end)

t:test("wide documentation stacks below a wide menu", function()
  local popupmenu = setup()
  local layout = assert(
    popupmenu._resolve_documentation_layout(
      { row = 3, col = 20, width = 45, height = 4, direction = "s" },
      56,
      12,
      23,
      96,
      1
    )
  )

  t.assert_eq(9, layout.row, "stacked row")
  t.assert_eq(20, layout.col, "stacked column")
  t.assert_eq(56, layout.width, "stacked width")
  t.assert_eq(12, layout.height, "stacked height")
end)

t:test("documentation sizes snippet previews without counting dividers", function()
  local popupmenu = setup()
  local uuid = "00010203-0405-4607-8809-0a0b0c0d0e0f"

  local lines, width, dividers, highlights =
    popupmenu._format_documentation("<preview>" .. uuid .. "<separator>A Version 4 UUID")

  t.assert_eq(3, #lines, "documentation rows")
  t.assert_eq(36, width, "preview width")
  t.assert_eq(1, #dividers, "divider count")
  t.assert_eq(2, dividers[1], "divider row")
  t.assert_eq("Special", highlights[1].group, "summary highlight")
  t.assert_eq(0, highlights[1].row, "summary row")
  t.assert_eq("NonText", highlights[2].group, "separator highlight")
  t.assert_eq(1, highlights[2].row, "separator row")
end)

t:test("documentation preserves snippet markdown syntax", function()
  local popupmenu = setup()
  local lines, _, dividers = popupmenu._format_documentation("<preview>---\n```{r}\nvalue\n```<separator>docs")

  t.assert_eq("---", lines[1], "preview horizontal rule")
  t.assert_eq("```{r}", lines[2], "preview opening fence")
  t.assert_eq("value", lines[3], "preview body")
  t.assert_eq("```", lines[4], "preview closing fence")
  t.assert_eq(1, #dividers, "internal divider count")
  t.assert_eq(5, dividers[1], "internal divider row")
  t.assert_eq("docs", lines[6], "documentation")
end)

t:test("documentation removes unrendered markdown fences", function()
  local popupmenu = setup()
  local lines = popupmenu._format_documentation("```lua\nfunction value()\n```\n\n---\n\ndocs")

  t.assert_eq(3, #lines, "visible rows")
  t.assert_eq("function value()", lines[1], "code line")
  t.assert_eq("---", lines[2], "divider")
  t.assert_eq("docs", lines[3], "documentation")
end)

t:test("documentation marks its buffer before setting the markdown filetype", function()
  local popupmenu, states = setup()
  states.popupmenu = {
    owner = "native",
    generation = 1,
    items = { { "candidate", "K", "[lsp]", "documentation" } },
    selected = -1,
    row = 0,
    col = 0,
    grid = -1,
    layout = { row = 1, col = 1, width = 20, height = 1, direction = "s" },
    doc_generation = 0,
  }

  local doc_bufnr = vim.api.nvim_create_buf(false, true)
  local deferred = nil ---@type function|nil
  local marked_before_filetype = false
  local winhighlight = nil ---@type string|nil
  t:patch_table(vim, "defer_fn", function(callback)
    deferred = callback
    return {
      is_closing = function()
        return false
      end,
      stop = function() end,
      close = function() end,
    }
  end)
  t:patch_table(vim.api, "nvim_create_buf", function()
    return doc_bufnr
  end)
  t:patch_table(vim.api, "nvim_set_option_value", function(name, value, opts)
    if name == "filetype" then
      marked_before_filetype = vim.b[opts.buf][dot.var.N_CMP_DOCUMENTATION] == true
    elseif name == "winhighlight" then
      winhighlight = value
    end
  end)
  t:patch_table(vim.api, "nvim_buf_set_lines", function() end)
  t:patch_table(vim.api, "nvim_open_win", function()
    return 99
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return false
  end)

  popupmenu.select({ event = "popupmenu_select", args = { 0 } })
  assert(deferred)()

  t.assert_true(marked_before_filetype, "render-markdown opt-out marker")
  t.assert_eq("Normal:f_up_normal,FloatBorder:f_cmp_border", winhighlight, "documentation border")
  vim.api.nvim_buf_delete(doc_bufnr, { force = true })
end)

t:test("documentation stays hidden until an item is selected", function()
  local popupmenu, states = setup()
  states.popupmenu = {
    owner = "native",
    generation = 1,
    items = { { "candidate", "K", "[lsp]", "documentation" } },
    selected = -1,
    row = 0,
    col = 0,
    grid = 1,
    bufnr = 1,
    winnr = 2,
    layout = { row = 1, col = 1, width = 20, height = 1 },
    doc_generation = 0,
  }
  local deferred = nil ---@type function|nil
  t:patch_table(vim, "defer_fn", function(callback)
    deferred = callback
    return {
      is_closing = function()
        return false
      end,
      stop = function() end,
      close = function() end,
    }
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_buf_clear_namespace", function() end)
  t:patch_table(vim.api, "nvim_buf_set_extmark", function()
    return 1
  end)
  t:patch_table(vim.api, "nvim_win_set_cursor", function() end)
  t:patch_table(vim.api, "nvim__redraw", function() end)

  popupmenu.select({ event = "popupmenu_select", args = { -1 } })
  t.assert_nil(deferred, "unselected timer")
  popupmenu.select({ event = "popupmenu_select", args = { 0 } })
  t.assert_true(deferred ~= nil, "selected timer")
end)

t:test("documentation can be toggled for the active menu", function()
  local popupmenu, states = setup()
  states.popupmenu = {
    owner = "native",
    generation = 1,
    items = { { "candidate", "K", "[lsp]", "documentation" } },
    selected = 0,
    row = 0,
    col = 0,
    grid = 1,
    doc_winnr = 2,
    doc_bufnr = 3,
    doc_generation = 0,
    doc_enabled = true,
  }
  local deferred = nil ---@type function|nil
  t:patch_table(vim, "defer_fn", function(callback)
    deferred = callback
    return {
      is_closing = function()
        return false
      end,
      stop = function() end,
      close = function() end,
    }
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_win_close", function() end)
  t:patch_table(vim.api, "nvim_buf_delete", function() end)

  t.assert_true(popupmenu.toggle_documentation(), "hide handled")
  t.assert_false(states.popupmenu.doc_enabled, "hidden state")
  t.assert_nil(states.popupmenu.doc_winnr, "hidden window")

  t.assert_true(popupmenu.toggle_documentation(), "show handled")
  t.assert_true(states.popupmenu.doc_enabled, "shown state")
  t.assert_true(deferred ~= nil, "show timer")

  popupmenu.hide({ event = "popupmenu_hide", args = {} })
  t.assert_nil(states.popupmenu, "dismissed state")
end)

t:test("documentation scrolls inside its own window", function()
  local popupmenu, states = setup()
  states.popupmenu = { owner = "native", generation = 1, doc_winnr = 7 }
  local keys = {} ---@type string[]
  local redraws = 0
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_win_call", function(winnr, callback)
    t.assert_eq(7, winnr, "documentation window")
    callback()
  end)
  t:patch_table(vim.cmd, "normal", function(opts)
    keys[#keys + 1] = opts.args[1]
  end)
  t:patch_table(vim.api, "nvim__redraw", function()
    redraws = redraws + 1
  end)

  t.assert_true(popupmenu.scroll_documentation(-1), "scroll up")
  t.assert_true(popupmenu.scroll_documentation(1), "scroll down")
  t.assert_eq(vim.keycode("<C-b>"), keys[1], "up key")
  t.assert_eq(vim.keycode("<C-f>"), keys[2], "down key")
  t.assert_eq(2, redraws, "redraw count")
end)

t:test("resolved documentation updates only the active selected item", function()
  local popupmenu, states = setup()
  states.popupmenu = {
    owner = "native",
    generation = 1,
    items = { { "first", "K", "[lsp]", "preview" }, { "second", "K", "[lsp]", "other" } },
    selected = 0,
    row = 0,
    col = 0,
    grid = 1,
    doc_timer = {},
  }

  popupmenu.update_documentation(1, "second", "stale")
  popupmenu.update_documentation(0, "wrong", "stale")
  t.assert_eq("preview", states.popupmenu.items[1][4], "stale update")

  popupmenu.update_documentation(0, "first", "resolved")
  t.assert_eq("resolved", states.popupmenu.items[1][4], "resolved update")
end)

t:run()
