local bootstrap = require("__test__.support.bootstrap")
local dressing = require("__test__.support.dressing")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_runtime(t, {
  stl = {
    filetype = require("stl.filetype"),
    nvim = {
      fn = require("stl.nvim.fn"),
    },
    timer = require("stl.timer"),
  },
  era = {
    dressing = {},
  },
})

local Indentscope = require("era.dressing.indentscope")
era.dressing.indentscope = Indentscope

-- Shows `lines` as two-space indented Lua in the current window; the drawn scope is cleared when the case ends.
---@param lines                         string[]
---@return integer
local function buffer(lines)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local foldmethod = vim.api.nvim_get_option_value("foldmethod", { win = winnr }) ---@type string
  local bufnr = t:buffer(lines, { filetype = "lua", current = true }) ---@type integer
  t:defer(function()
    Indentscope.undraw()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_set_option_value("foldmethod", foldmethod, { win = winnr })
    end
  end)
  vim.api.nvim_set_option_value("expandtab", true, { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", 2, { buf = bufnr })
  return bufnr
end

-- Redraws the window (the current one by default) and returns the rows it draws guides on, in order.
---@param winnr                         integer|nil
---@return integer[]
local function render(winnr)
  require("era.dressing.indentscope.draw")
  local namespace = vim.api.nvim_get_namespaces()["era.dressing.indentscope"] ---@type integer
  local extmarks = dressing.ephemeral_extmarks(t, namespace, function()
    vim.api.nvim__redraw({ win = winnr or vim.api.nvim_get_current_win(), valid = false, flush = true })
  end)
  local rows = {} ---@type integer[]
  for _, extmark in ipairs(extmarks) do
    rows[#rows + 1] = extmark.row
  end
  table.sort(rows)
  return rows
end

-- The character on the screen at display column `col` (0 by default) of line `lnum` in `winnr`.
---@param winnr                         integer
---@param lnum                          integer
---@param col                           ?integer
---@return string
local function screen_char(winnr, lnum, col)
  local position = vim.api.nvim_win_get_position(winnr) ---@type integer[]
  local info = vim.fn.getwininfo(winnr)[1] ---@type table
  local topline = vim.api.nvim_win_call(winnr, function()
    return vim.fn.line("w0")
  end) ---@type integer
  return vim.fn.screenstring(position[1] + lnum - topline + 1, position[2] + info.textoff + (col or 0) + 1)
end

t:test("init keeps rendering and actions lazy", function()
  t.assert_nil(package.loaded["era.dressing.indentscope.draw"], "draw loaded during init")
  t.assert_nil(package.loaded["era.dressing.indentscope.action"], "action loaded during init")
end)

t:test("try_as_border resolves the nested scope from its header", function()
  buffer({ "function outer()", "  if ok then", "    call()", "  end", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope()

  t.assert_eq(3, scope.reference.line, "reference line")
  t.assert_eq(3, scope.body.top, "body top")
  t.assert_eq(3, scope.body.bottom, "body bottom")
  t.assert_eq(2, scope.border.top, "border top")
  t.assert_eq(4, scope.border.bottom, "border bottom")
  t.assert_eq(2, scope.border.indent, "border indent")
end)

t:test("border policy controls blank lines at scope edges", function()
  buffer({ "function outer()", "", "    call()", "", "  end" })
  vim.api.nvim_win_set_cursor(0, { 3, 4 })

  local both = Indentscope.get_scope(nil, nil, { border = "both", try_as_border = false })
  local top = Indentscope.get_scope(nil, nil, { border = "top", try_as_border = false })
  local bottom = Indentscope.get_scope(nil, nil, { border = "bottom", try_as_border = false })
  local none = Indentscope.get_scope(nil, nil, { border = "none", try_as_border = false })

  t.assert_eq(2, both.body.top, "both top")
  t.assert_eq(4, both.body.bottom, "both bottom")
  t.assert_eq(2, top.body.top, "top top")
  t.assert_eq(3, top.body.bottom, "top bottom")
  t.assert_eq(3, bottom.body.top, "bottom top")
  t.assert_eq(4, bottom.body.bottom, "bottom bottom")
  t.assert_eq(3, none.body.top, "none top")
  t.assert_eq(3, none.body.bottom, "none bottom")
end)

t:test("scope scans beyond the former line limit", function()
  local lines = {} ---@type string[]
  for index = 1, 8193 do
    lines[index] = "  line"
  end

  buffer(lines)
  vim.api.nvim_win_set_cursor(0, { 4097, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })

  t.assert_eq(1, scope.body.top, "scope top")
  t.assert_eq(8193, scope.body.bottom, "scope bottom")
end)

t:test("scope cache reuses unchanged boundaries and invalidates on edits", function()
  local lines = { "root" } ---@type string[]
  for index = 2, 201 do
    lines[index] = "  line"
  end
  lines[202] = "tail"

  local bufnr = buffer(lines)
  vim.api.nvim_win_set_cursor(0, { 150, 2 })
  local first = Indentscope.get_scope(nil, nil, { try_as_border = false })
  t.assert_eq(2, first.body.top, "initial scope top")
  t.assert_eq(201, first.body.bottom, "initial scope bottom")

  local original_indent = vim.fn.indent
  local indent_calls = 0 ---@type integer
  t:patch_table(vim.fn, "indent", function(...)
    indent_calls = indent_calls + 1
    return original_indent(...)
  end)

  vim.api.nvim_win_set_cursor(0, { 151, 2 })
  local reused = Indentscope.get_scope(nil, nil, { try_as_border = false })
  t.assert_eq(2, reused.body.top, "reused scope top")
  t.assert_eq(201, reused.body.bottom, "reused scope bottom")
  t.assert_eq(1, indent_calls, "cached indent reads")

  indent_calls = 0
  vim.api.nvim_buf_set_lines(bufnr, 119, 120, false, { "break" })
  local invalidated = Indentscope.get_scope(nil, nil, { try_as_border = false })
  t.assert_eq(121, invalidated.body.top, "invalidated scope top")
  t.assert_eq(201, invalidated.body.bottom, "invalidated scope bottom")
  t.assert_true(indent_calls > 50, "edit forces a full scan")
end)

t:test("draw renders one guide on every scope body line", function()
  local bufnr = buffer({ "if ok then", "  one()", "  two()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })

  local rows = render(nil)
  t.assert_eq(2, #rows, "guide count")
  t.assert_eq(1, rows[1], "first guide row")
  t.assert_eq(2, rows[2], "second guide row")

  local namespace = vim.api.nvim_get_namespaces()["era.dressing.indentscope"] ---@type integer
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {}) ---@type table[]
  t.assert_eq(0, #extmarks, "persistent extmark count")
end)

t:test("draw clips guides to the current viewport", function()
  local lines = { "root" } ---@type string[]
  for index = 2, 201 do
    lines[index] = "  line"
  end
  lines[202] = "tail"

  buffer(lines)
  vim.api.nvim_win_set_cursor(0, { 101, 2 })
  vim.cmd("normal! zz")
  local visible_top = vim.fn.line("w0") ---@type integer
  local visible_bottom = vim.fn.line("w$") ---@type integer
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })

  local rows = render(nil)
  t.assert_eq(visible_bottom - visible_top + 1, #rows, "viewport guide count")
  t.assert_eq(visible_top - 1, rows[1], "first viewport row")
  t.assert_eq(visible_bottom - 1, rows[#rows], "last viewport row")
  t.assert_true(#rows < scope.body.bottom - scope.body.top + 1, "scope is clipped")
end)

t:test("draw renders only in the active window for a shared buffer", function()
  buffer({
    "function outer()",
    "  if one then",
    "    one()",
    "  end",
    "  if two then",
    "    two()",
    "  end",
    "end",
  })
  local inactive_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_cursor(inactive_winnr, { 3, 4 })
  vim.cmd("vsplit")
  local active_winnr = vim.api.nvim_get_current_win() ---@type integer
  t:defer(function()
    if vim.api.nvim_win_is_valid(active_winnr) then
      vim.api.nvim_win_close(active_winnr, true)
    end
  end)
  vim.api.nvim_win_set_cursor(active_winnr, { 6, 4 })

  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })
  vim.api.nvim__redraw({ valid = false, flush = true })

  t.assert_eq("╎", screen_char(active_winnr, 6, 2), "active window guide")
  t.assert_eq(" ", screen_char(inactive_winnr, 6, 2), "inactive window guide")

  vim.api.nvim_set_current_win(inactive_winnr)
  scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })
  -- Headless scripts have no idle redraw; static frames are not flushed outside the command line.
  vim.api.nvim__redraw({ flush = true })

  t.assert_eq("╎", screen_char(inactive_winnr, 3, 2), "new active window guide")
  t.assert_eq(" ", screen_char(active_winnr, 6, 2), "previous active window guide")
end)

t:test("restarting animation clears the previous scope immediately", function()
  buffer({
    "if first then",
    "  first_a()",
    "  first_b()",
    "end",
    "",
    "if second then",
    "  second_a()",
    "  second_b()",
    "  second_c()",
    "end",
  })
  local winnr = vim.api.nvim_get_current_win() ---@type integer

  vim.api.nvim_win_set_cursor(winnr, { 2, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })
  -- Headless scripts have no idle redraw; the static frame waits for the next redraw.
  vim.api.nvim__redraw({ flush = true })
  t.assert_eq("╎", screen_char(winnr, 2), "previous scope guide")

  vim.api.nvim_win_set_cursor(winnr, { 8, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), {
    interval = 100,
    max_duration = 600,
  })

  t.assert_eq(" ", screen_char(winnr, 2), "previous scope cleared")
  t.assert_eq("╎", screen_char(winnr, 8), "new origin guide")
end)

t:test("changing scope clears guide rows outside the new body", function()
  buffer({ "if ok then", "  one()", "  two()", "  three()", "end" })
  local winnr = vim.api.nvim_get_current_win() ---@type integer

  vim.api.nvim_win_set_cursor(winnr, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })
  vim.api.nvim__redraw({ flush = true })
  t.assert_eq("╎", screen_char(winnr, 4), "previous guide")

  local narrowed = vim.deepcopy(scope)
  narrowed.body.bottom = 3
  Indentscope.draw(narrowed, { interval = 0 })
  vim.api.nvim__redraw({ flush = true })
  t.assert_eq("╎", screen_char(winnr, 3), "kept guide")
  t.assert_eq(" ", screen_char(winnr, 4), "cleared guide")
end)

t:test("scope changes redraw guide rows until the buffer changes", function()
  local bufnr = buffer({ "if first then", "  first()", "end", "if second then", "  second()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })

  local redraws = {} ---@type table[]
  local original = vim.api.nvim__redraw
  t:patch_table(vim.api, "nvim__redraw", function(options)
    redraws[#redraws + 1] = options
    return original(options)
  end)

  vim.api.nvim_win_set_cursor(0, { 5, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })
  t.assert_eq(2, #redraws, "redraw count")
  t.assert_eq("1:2", table.concat(redraws[1].range or {}, ":"), "previous guide rows")
  t.assert_eq("4:5", table.concat(redraws[2].range or {}, ":"), "current guide rows")

  redraws = {}
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "-- shifted" })
  vim.api.nvim_win_set_cursor(0, { 3, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })
  t.assert_eq(false, redraws[1].valid, "moved guide rows redraw the window")
end)

t:test("draw skips lines hidden inside a closed fold", function()
  local lines = { "root" } ---@type string[]
  for index = 2, 201 do
    lines[index] = "  line"
  end
  lines[202] = "tail"

  buffer(lines)
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = 0 })
  vim.cmd("2,201fold")
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  vim.cmd("normal! zc")
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })

  local rows = render(nil)
  t.assert_eq(1, #rows, "fold guide count")
  t.assert_eq(1, rows[1], "fold start row")
end)

t:test("draw refreshes when a fold opens or closes", function()
  local lines = { "root" } ---@type string[]
  for index = 2, 101 do
    lines[index] = "  line"
  end
  lines[102] = "tail"

  buffer(lines)
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = 0 })
  vim.cmd("2,101fold")
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  vim.cmd("normal! zc")
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })

  local function guide_count()
    return #render(nil)
  end

  t.assert_eq(1, guide_count(), "closed fold")
  vim.cmd("normal! zo")
  vim.cmd("redraw")
  t.wait_until(function()
    return guide_count() > 1
  end, 5000, "opened fold redraw")

  vim.cmd("normal! zc")
  vim.cmd("redraw")
  t.wait_until(function()
    return guide_count() == 1
  end, 5000, "closed fold redraw")
end)

t:test("draw suppresses a scope spanning the whole indented buffer", function()
  buffer({ "  one()", "  two()", "  three()" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })

  t.assert_eq(-1, scope.border.indent, "imaginary border indent")
  t.assert_eq(0, #render(nil), "guide count")
end)

t:test("animated draw completes within the configured frame budget", function()
  buffer({ "if ok then", "  one", "  two", "  three", "  four", "  five", "  six", "  seven", "end" })
  local timer = dressing.timer()
  t:patch_table(vim, "schedule_wrap", function(callback)
    return callback
  end)
  t:patch_table(vim.uv, "new_timer", function()
    return timer
  end)

  vim.api.nvim_win_set_cursor(0, { 5, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  -- Three layers to reveal, but the budget only fits two frames: each frame reveals more.
  Indentscope.draw(scope, { interval = 20, max_duration = 40 })

  t.assert_eq(20, timer.timeout, "first frame interval")
  t.assert_eq(20, timer.repeat_ms, "frame interval")
  local frames = 0 ---@type integer
  while #render(nil) < 7 and frames < 10 do
    timer.callback()
    frames = frames + 1
  end
  t.assert_eq(7, #render(nil), "final frame")
  t.assert_true(frames * 20 <= 40, "frames fit the budget, got " .. frames)
end)

t:test("real timer preserves an intermediate animation frame", function()
  buffer({ "if ok then", "  one", "  two", "  three", "  four", "  five", "  six", "  seven", "end" })
  vim.api.nvim_win_set_cursor(0, { 5, 2 })
  local winnr = vim.api.nvim_get_current_win() ---@type integer

  local function guide_count()
    local count = 0 ---@type integer
    for lnum = 2, 8 do
      if screen_char(winnr, lnum) == "╎" then
        count = count + 1
      end
    end
    return count
  end

  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 100, max_duration = 600 })
  t.assert_eq(1, guide_count(), "origin frame")

  -- Each timer tick flushes its frame, and the wait checks after every event, so the 100 ms frame is seen.
  t.wait_until(function()
    return guide_count() == 3
  end, 5000, "intermediate frame")
  t.wait_until(function()
    -- Animation frames flush themselves; the finished static frame waits for the next redraw.
    vim.api.nvim__redraw({ flush = true })
    return guide_count() == 7
  end, 5000, "animation completion")
end)

t:test("animation reveals one scope layer per frame", function()
  buffer({ "if ok then", "  one", "  two", "  three", "  four", "  five", "  six", "  seven", "end" })
  t:patch_table(vim, "schedule_wrap", function(callback)
    return callback
  end)
  local timers = dressing.timers(t)

  vim.api.nvim_win_set_cursor(0, { 5, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })

  Indentscope.draw(scope, { interval = 20, max_duration = 300 })
  t.assert_eq(1, #render(nil), "origin frame")
  timers[1].callback()
  t.assert_eq(3, #render(nil), "first frame")
  timers[1].callback()
  t.assert_eq(5, #render(nil), "second frame")
  timers[1].callback()
  t.assert_eq(7, #render(nil), "final frame")
end)

t:test("animation limits each frame to new line ranges", function()
  buffer({ "if ok then", "  one", "  two", "  three", "  four", "  five", "  six", "  seven", "end" })
  local redraws = {} ---@type table[]
  t:patch_table(vim, "schedule_wrap", function(callback)
    return callback
  end)
  local timers = dressing.timers(t)
  t:patch_table(vim.api, "nvim__redraw", function(options)
    redraws[#redraws + 1] = options
  end)

  vim.api.nvim_win_set_cursor(0, { 5, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 20, max_duration = 300 })

  t.assert_eq(1, #redraws, "origin redraw count")
  t.assert_true(redraws[1].range ~= nil, "origin redraw range")

  redraws = {}
  timers[1].callback()
  t.assert_eq(2, #redraws, "frame redraw count")
  t.assert_eq(1, redraws[1].range[2] - redraws[1].range[1], "upper range size")
  t.assert_eq(1, redraws[2].range[2] - redraws[2].range[1], "lower range size")
  t.assert_false(redraws[1].flush, "upper range flush")
  t.assert_true(redraws[2].flush, "lower range flush")
end)

t:test("stale animation callback does not clear the current timer", function()
  buffer({ "if ok then", "  one()", "  two()", "end" })
  local queued = {} ---@type fun()[]

  t:patch_table(vim, "schedule_wrap", function(callback)
    return function(...)
      local args = { ... }
      queued[#queued + 1] = function()
        callback(unpack(args))
      end
    end
  end)
  local timers = dressing.timers(t)

  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local first_scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(first_scope, { interval = 10, max_duration = 100 })
  timers[1].callback()

  vim.api.nvim_win_set_cursor(0, { 3, 2 })
  local second_scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(second_scope, { interval = 10, max_duration = 100 })
  queued[1]()

  t.assert_false(timers[2].closing, "current timer")
end)

t:test("waiting refresh restarts delay with the latest reference", function()
  buffer({ "if ok then", "  one()", "  two()", "end" })
  local deferred = {} ---@type { callback: fun(), timer: table }[]

  t:patch_table(vim, "defer_fn", function(callback)
    local timer = dressing.timer()
    deferred[#deferred + 1] = { callback = callback, timer = timer }
    return timer
  end)
  local timers = dressing.timers(t)

  local Draw = require("era.dressing.indentscope.draw")
  local options = {
    delay = 100,
    interval = 10,
    max_duration = 100,
    priority = 2,
    symbol = "╎",
    highlights = { "Normal" },
  } ---@type era.dressing.indentscope.IDrawOptions

  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Draw.refresh(Indentscope.get_scope(nil, nil, { try_as_border = false }), options, true)
  vim.api.nvim_win_set_cursor(0, { 3, 2 })
  Draw.refresh(Indentscope.get_scope(nil, nil, { try_as_border = false }), options, true)

  t.assert_eq(2, #deferred, "deferred draws")
  t.assert_true(deferred[1].timer.closing, "first delay timer")
  deferred[2].callback()

  local rows = render(nil)
  t.assert_eq(1, #rows, "initial animation guides")
  t.assert_eq(2, rows[1], "latest reference row")
  t.assert_eq(1, #timers, "animation timers")
end)

t:test("eligibility is owned by indentscope", function()
  local bufnr = buffer({ "if ok then", "  one()", "end" })
  t.assert_true(Indentscope.is_enabled(bufnr), "source buffer")

  for _, filetype in ipairs({ "", stl.filetype.BIGFILE, stl.filetype.BOARD, "diff" }) do
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    t.assert_false(Indentscope.is_enabled(bufnr), filetype == "" and "empty filetype" or filetype)
  end

  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "prompt", { buf = bufnr })
  t.assert_false(Indentscope.is_enabled(bufnr), "prompt buffer")
end)

t:test("excluded filetype suppresses drawing", function()
  local bufnr = buffer({ "if ok then", "  one()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = bufnr })
  Indentscope.draw(scope, { interval = 0 })

  t.assert_eq(0, #render(nil), "guide count")
end)

t:test("FileType immediately removes an ineligible scope", function()
  local bufnr = buffer({ "if ok then", "  one()", "end" })
  Indentscope.dressing()
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })
  t.assert_eq(1, #render(nil), "eligible guide count")

  vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = bufnr })
  t.assert_eq(0, #render(nil), "ineligible guide count")
end)

t:test("hidden FileType events preserve the active scope", function()
  buffer({ "if ok then", "  one()", "end" })
  Indentscope.dressing()
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })
  Indentscope.draw(scope, { interval = 0 })
  t.assert_eq(1, #render(nil), "active guide count")

  local hidden_bufnr = t:buffer() ---@type integer
  vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = hidden_bufnr })
  t.assert_eq(1, #render(nil), "guide count after hidden FileType")
end)

t:test("move_cursor chooses border or body", function()
  buffer({ "if ok then", "  one()", "  two()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })

  Indentscope.move_cursor("bottom", true, scope)
  t.assert_eq(4, vim.api.nvim_win_get_cursor(0)[1], "bottom border")

  Indentscope.move_cursor("top", false, scope)
  t.assert_eq(2, vim.api.nvim_win_get_cursor(0)[1], "top body")
end)

t:test("inner textobject selects the scope body linewise", function()
  buffer({ "if ok then", "  one()", "  two()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Indentscope.textobject(false)
  vim.cmd("normal! y")

  t.assert_eq("  one()\n  two()\n", vim.fn.getreg('"'), "yanked scope")
end)

t:test("excluded CursorMoved skips scope computation", function()
  local bufnr = buffer({ "  one()", "  two()" })
  local Scope = require("era.dressing.indentscope.scope")
  local calls = 0 ---@type integer
  t:patch_table(Scope, "get", function()
    calls = calls + 1
    error("disabled scope computation")
  end)

  vim.api.nvim_set_option_value("filetype", stl.filetype.BOARD, { buf = bufnr })
  Indentscope.dressing()
  vim.api.nvim_exec_autocmds("CursorMoved", { modeline = false })

  t.assert_eq(0, calls, "scope calls")
end)

t:test("window and buffer entry refresh the active scope", function()
  buffer({ "if ok then", "  one()", "end" })
  local Scope = require("era.dressing.indentscope.scope")
  local original = Scope.get
  local calls = 0 ---@type integer
  t:patch_table(Scope, "get", function(...)
    calls = calls + 1
    return original(...)
  end)

  Indentscope.dressing()
  vim.api.nvim_exec_autocmds("WinEnter", { modeline = false })
  vim.api.nvim_exec_autocmds("BufWinEnter", { modeline = false })

  t.assert_eq(2, calls, "scope calls")
end)

t:test("Insert submode changes skip scope computation", function()
  buffer({ "if ok then", "  one()", "end" })
  local Scope = require("era.dressing.indentscope.scope")
  local original = Scope.get
  local calls = 0 ---@type integer
  t:patch_table(Scope, "get", function(...)
    calls = calls + 1
    return original(...)
  end)

  Indentscope.dressing()
  for _, transition in ipairs({ "i:ic", "ic:i", "ix:ic" }) do
    vim.api.nvim_exec_autocmds("ModeChanged", { pattern = transition, modeline = false })
  end
  t.assert_eq(0, calls, "scope calls within Insert mode")

  vim.api.nvim_exec_autocmds("ModeChanged", { pattern = "ic:n", modeline = false })
  t.assert_eq(1, calls, "scope calls on leaving Insert mode")
end)

t:test("WinScrolled updates layout without recomputing scope", function()
  buffer({ "if ok then", "  one()", "  two()", "end" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })

  local Scope = require("era.dressing.indentscope.scope")
  local calls = 0 ---@type integer
  t:patch_table(Scope, "get", function()
    calls = calls + 1
    error("WinScrolled recomputed scope")
  end)

  Indentscope.dressing()
  vim.api.nvim_exec_autocmds("WinScrolled", { modeline = false })

  t.assert_eq(0, calls, "scope calls")
end)

t:test("WinScrolled keeps a finished scope without redrawing the window", function()
  local lines = { "root" } ---@type string[]
  for index = 2, 201 do
    lines[index] = "  line"
  end
  lines[202] = "tail"

  buffer(lines)
  vim.api.nvim_win_set_cursor(0, { 101, 2 })
  vim.cmd("normal! zz")
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })
  Indentscope.dressing()

  local redraws = 0 ---@type integer
  local original = vim.api.nvim__redraw
  t:patch_table(vim.api, "nvim__redraw", function(options)
    redraws = redraws + 1
    return original(options)
  end)
  vim.cmd("normal! 20" .. vim.keycode("<C-e>"))
  vim.api.nvim_exec_autocmds("WinScrolled", { modeline = false })
  t.assert_eq(0, redraws, "redraw requests")

  local rows = render(nil)
  t.assert_eq(vim.fn.line("w0") - 1, rows[1], "first guide row")
  t.assert_eq(vim.fn.line("w$") - 1, rows[#rows], "last guide row")
end)

t:test("an edit that keeps the scope and every row in place redraws nothing", function()
  local bufnr = buffer({ "if ok then", "  one()", "  two()", "end", "tail" })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), { interval = 0 })
  Indentscope.dressing()

  local redraws = {} ---@type table[]
  local original = vim.api.nvim__redraw
  t:patch_table(vim.api, "nvim__redraw", function(options)
    redraws[#redraws + 1] = options
    return original(options)
  end)
  vim.api.nvim_buf_set_text(bufnr, 1, 7, 1, 7, { " -- note" })
  vim.api.nvim_exec_autocmds("TextChanged", { modeline = false })
  t.assert_eq(0, #redraws, "redraw requests")
  t.assert_eq("1,2", table.concat(render(nil), ","), "guide rows")

  redraws = {}
  vim.api.nvim_buf_set_lines(bufnr, 2, 2, false, { "  three()" })
  vim.api.nvim_exec_autocmds("TextChanged", { modeline = false })
  t.assert_true(#redraws > 0, "moved rows redraw")
  t.assert_eq("1,2,3", table.concat(render(nil), ","), "guide rows after the insert")
end)

t:run()
