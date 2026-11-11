local dressing = require("__test__.support.dressing")
local harness = require("__test__.support.harness")

local t = harness.new()
local Indentscope = dressing.with_indentscope(t)

-- A scope of seven lines around line 5: an animation reveals it from there in three layers.
local layered_lines = { "if ok then", "  one", "  two", "  three", "  four", "  five", "  six", "  seven", "end" }

t:test("restarting animation clears the previous scope immediately", function()
  dressing.indentscope_buffer(t, {
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
  t.assert_eq("╎", dressing.screen_char(winnr, 2), "previous scope guide")

  vim.api.nvim_win_set_cursor(winnr, { 8, 2 })
  Indentscope.draw(Indentscope.get_scope(nil, nil, { try_as_border = false }), {
    interval = 100,
    max_duration = 600,
  })

  t.assert_eq(" ", dressing.screen_char(winnr, 2), "previous scope cleared")
  t.assert_eq("╎", dressing.screen_char(winnr, 8), "new origin guide")
end)

t:test("animated draw completes within the configured frame budget", function()
  dressing.indentscope_buffer(t, layered_lines)
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
  while #dressing.indentscope_rows(t) < 7 and frames < 10 do
    timer.callback()
    frames = frames + 1
  end
  t.assert_eq(7, #dressing.indentscope_rows(t), "final frame")
  t.assert_true(frames * 20 <= 40, "frames fit the budget, got " .. frames)
end)

t:test("real timer preserves an intermediate animation frame", function()
  dressing.indentscope_buffer(t, layered_lines)
  vim.api.nvim_win_set_cursor(0, { 5, 2 })
  local winnr = vim.api.nvim_get_current_win() ---@type integer

  local function guide_count()
    local count = 0 ---@type integer
    for lnum = 2, 8 do
      if dressing.screen_char(winnr, lnum) == "╎" then
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
  dressing.indentscope_buffer(t, layered_lines)
  t:patch_table(vim, "schedule_wrap", function(callback)
    return callback
  end)
  local timers = dressing.timers(t)

  vim.api.nvim_win_set_cursor(0, { 5, 2 })
  local scope = Indentscope.get_scope(nil, nil, { try_as_border = false })

  Indentscope.draw(scope, { interval = 20, max_duration = 300 })
  t.assert_eq(1, #dressing.indentscope_rows(t), "origin frame")
  timers[1].callback()
  t.assert_eq(3, #dressing.indentscope_rows(t), "first frame")
  timers[1].callback()
  t.assert_eq(5, #dressing.indentscope_rows(t), "second frame")
  timers[1].callback()
  t.assert_eq(7, #dressing.indentscope_rows(t), "final frame")
end)

t:test("animation limits each frame to new line ranges", function()
  dressing.indentscope_buffer(t, layered_lines)
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
  dressing.indentscope_buffer(t, { "if ok then", "  one()", "  two()", "end" })
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
  dressing.indentscope_buffer(t, { "if ok then", "  one()", "  two()", "end" })
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

  local rows = dressing.indentscope_rows(t)
  t.assert_eq(1, #rows, "initial animation guides")
  t.assert_eq(2, rows[1], "latest reference row")
  t.assert_eq(1, #timers, "animation timers")
end)

t:run()
