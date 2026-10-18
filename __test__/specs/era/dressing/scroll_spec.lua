--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/scroll_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.dressing.scroll module

local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.scroll")

---@param callback                     function
---@param name                         string
---@return any
local function get_upvalue(callback, name)
  local index = 1
  while true do
    local upvalue_name, value = debug.getupvalue(callback, index)
    if upvalue_name == nil then
      break
    end
    if upvalue_name == name then
      return value
    end
    index = index + 1
  end
  error("missing upvalue: " .. name)
end

---@class era.dressing.scroll.test.ITimer
---@field callback                     fun()|nil
---@field cleared                      boolean
local Timer = {}
Timer.__index = Timer

---@param _timeout                      integer
---@param _interval                     integer
---@param callback                      fun()
---@return nil
function Timer:start(_timeout, _interval, callback)
  self.callback = callback
end

---@class era.dressing.scroll.test.IRuntime
---@field autocmds                      table<string, table>
---@field bufnr                         integer
---@field valid                         boolean
---@field height                        integer
---@field width                         integer Screen columns of one wrapped screen line.
---@field heights                       table<integer, integer> Screen lines of each 0-based row, one by default.
---@field cursors                       integer[][] Cursors placed through nvim_win_set_cursor.
---@field float                         boolean
---@field view                          vim.fn.winsaveview.ret
---@field options                       table<string, any>
---@field scheduled                     fun()[]
---@field timers                        era.dressing.scroll.test.ITimer[]
---@field observer                      fun()
---@field on_key                        fun(key: string, typed: string)|nil
---@field observe_calls                 integer
---@field enabled                       boolean
---@field Scroll                        era.dressing.scroll
---@field check_scroll                  fun(winnr: integer)
---@field states                        table<integer, era.dressing.scroll.IState>
---@field get_states                    fun(): table<integer, era.dressing.scroll.IState>

---@return era.dressing.scroll.test.IRuntime
local function setup()
  local runtime = {
    autocmds = {},
    bufnr = 1,
    valid = true,
    height = 200,
    width = 80,
    heights = {},
    cursors = {},
    float = false,
    view = { lnum = 1, col = 0, coladd = 0, curswant = 0, topline = 1, topfill = 0, leftcol = 0, skipcol = 0 },
    options = { virtualedit = "", scrolloff = 4, scrollbind = false },
    scheduled = {},
    timers = {},
    observe_calls = 0,
    enabled = true,
  } ---@type era.dressing.scroll.test.IRuntime

  t:patch_global("stl", {
    easing = {
      outQuad = function(_, _, _, _)
        return 0
      end,
    },
    fn = {
      observe = function(_, callback)
        runtime.observe_calls = runtime.observe_calls + 1
        runtime.observer = callback
        callback()
      end,
    },
    nvim = {
      fn = {
        augroup = function(name)
          return name
        end,
      },
    },
    timer = {
      clear_timer = function(timer)
        timer.cleared = true
      end,
    },
  })
  t:patch_global("dot", {
    context = {
      flight = {
        dressing_scroll = {
          snapshot = function()
            return runtime.enabled
          end,
        },
      },
    },
  })

  t:patch_table(vim, "schedule", function(callback)
    runtime.scheduled[#runtime.scheduled + 1] = callback
  end)
  t:patch_table(vim, "on_key", function(callback, _)
    if callback ~= nil then
      runtime.on_key = callback
    end
    return 1
  end)
  t:patch_table(vim.uv, "new_timer", function()
    local timer = setmetatable({ callback = nil, cleared = false }, Timer)
    runtime.timers[#runtime.timers + 1] = timer
    return timer
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
    runtime.autocmds[type(event) == "string" and event or table.concat(event, ",")] = opts
    return 1
  end)
  t:patch_table(vim.api, "nvim_clear_autocmds", function() end)
  t:patch_table(vim.api, "nvim_list_wins", function()
    return { 1 }
  end)
  t:patch_table(vim.api, "nvim_tabpage_list_wins", function()
    return { 1, 2 }
  end)
  t:patch_table(vim.api, "nvim_win_get_config", function(winnr)
    return { relative = winnr == 2 and runtime.float and "editor" or "" }
  end)
  t:patch_table(vim.api, "nvim_win_get_height", function()
    return runtime.height
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return runtime.valid
  end)
  t:patch_table(vim.api, "nvim_win_get_buf", function()
    return runtime.bufnr
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function(bufnr)
    return bufnr == runtime.bufnr
  end)
  t:patch_table(vim.api, "nvim_buf_get_changedtick", function()
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_current_win", function()
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_option_value", function(name)
    if name == "buftype" then
      return ""
    end
    return runtime.options[name]
  end)
  t:patch_table(vim.api, "nvim_set_option_value", function(name, value)
    runtime.options[name] = value
  end)
  t:patch_table(vim.api, "nvim_win_call", function(_, callback)
    return callback()
  end)
  t:patch_table(vim.api, "nvim_win_text_height", function(_, opts)
    -- A start column skips the screen lines before it; an exclusive end column keeps only those before it.
    local all = 0 ---@type integer
    for row = opts.start_row, opts.end_row do
      local first, last = 0, runtime.heights[row] or 1
      if row == opts.start_row and opts.start_vcol then
        first = math.floor(opts.start_vcol / runtime.width)
      end
      if row == opts.end_row and opts.end_vcol then
        last = math.ceil(opts.end_vcol / runtime.width)
      end
      all = all + math.max(last - first, 0)
    end
    return { all = all }
  end)
  t:patch_table(vim.fn, "winsaveview", function()
    return vim.deepcopy(runtime.view)
  end)
  t:patch_table(vim.fn, "winrestview", function(view)
    runtime.view = vim.deepcopy(view)
  end)
  t:patch_table(vim.fn, "winline", function()
    return runtime.view.lnum - runtime.view.topline + 1
  end)
  t:patch_table(vim.fn, "virtcol", function(pos)
    return pos[2] + 1
  end)
  t:patch_table(vim.fn, "virtcol2col", function(_, _, vcol)
    return vcol
  end)
  t:patch_table(vim.fn, "line", function(expr)
    assert(expr == "w$", "unexpected line() query: " .. tostring(expr))
    return runtime.view.topline + runtime.height - 1
  end)
  t:patch_table(vim.api, "nvim_win_set_cursor", function(_, cursor)
    runtime.cursors[#runtime.cursors + 1] = cursor
  end)

  runtime.Scroll = assert(loadfile("lua/era/dressing/scroll.lua"))()
  runtime.Scroll.dressing()

  local win_scrolled = runtime.autocmds.WinScrolled.callback ---@type function
  runtime.check_scroll = get_upvalue(win_scrolled, "check_scroll")
  local get_state = get_upvalue(runtime.check_scroll, "get_state") ---@type function
  runtime.states = get_upvalue(get_state, "states")
  runtime.get_states = function()
    return get_upvalue(get_state, "states")
  end
  return runtime
end

---@param runtime                       era.dressing.scroll.test.IRuntime
---@param view                          vim.fn.winsaveview.ret
---@return { restores: vim.fn.winsaveview.ret[], cursor: integer[]|nil, virtualedit: string|nil, commands: string[] }
local function finish_animation(runtime, view)
  local result = { restores = {}, cursor = nil, virtualedit = nil, commands = {} }
  t:patch_table(vim, "cmd", function(command)
    result.commands[#result.commands + 1] = command
  end)
  t:patch_table(vim.fn, "winrestview", function(restored)
    result.restores[#result.restores + 1] = restored
    result.virtualedit = runtime.options.virtualedit
    runtime.view = vim.deepcopy(restored)
  end)
  t:patch_table(vim.fn, "cursor", function(position)
    result.cursor = position
    result.virtualedit = runtime.options.virtualedit
  end)

  local timer = runtime.timers[#runtime.timers]
  while runtime.states[1].timer == timer do
    if #runtime.scheduled == 0 then
      assert(timer.callback)()
    end
    -- Scroll commands are stubbed; frames observe the view they would reach.
    runtime.view = vim.deepcopy(view)
    table.remove(runtime.scheduled, 1)()
  end
  return result
end

t:test("dressing subscribes once across repeated setup and feature toggles", function()
  local runtime = setup()

  runtime.Scroll.dressing()
  t.assert_eq(1, runtime.observe_calls, "observer registrations while enabled")

  runtime.enabled = false
  runtime.observer()
  runtime.Scroll.dressing()
  t.assert_eq(1, runtime.observe_calls, "observer registrations while disabled")
  t.assert_nil(runtime.get_states()[1], "disabled window state")

  runtime.enabled = true
  runtime.observer()
  runtime.Scroll.dressing()
  t.assert_eq(1, runtime.observe_calls, "observer registrations after re-enabling")
  t.assert_true(runtime.get_states()[1] ~= nil, "re-enabled window state")
end)

t:test("animates an unaccepted programmatic view change", function()
  local runtime = setup()

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)

  t.assert_eq(1, #runtime.timers, "animation timers")
  t.assert_true(runtime.states[1].timer == runtime.timers[1], "active animation timer")
end)

t:test("renderer-owned cursors do not start scroll animations", function()
  local runtime = setup()
  for _, filetype in ipairs({ "explorer", "treeview" }) do
    runtime.options.filetype = filetype
    runtime.view.lnum = 100
    runtime.view.topline = 100
    runtime.check_scroll(1)
    t.assert_eq(0, #runtime.timers, "animation timers for " .. filetype)
    t.assert_nil(runtime.get_states()[1], "animation state for " .. filetype)
  end
end)

t:test("switching to an Explorer buffer releases animation options and queued work", function()
  local runtime = setup()
  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)
  local timer = runtime.timers[1]
  assert(timer.callback)()

  runtime.bufnr = 2
  runtime.options.filetype = "explorer"
  runtime.view.lnum = 2
  runtime.view.topline = 1
  runtime.check_scroll(1)

  t.assert_true(timer.cleared, "timer cleared")
  t.assert_nil(runtime.get_states()[1], "animation state")
  t.assert_eq("", runtime.options.virtualedit, "restored virtualedit")
  t.assert_eq(4, runtime.options.scrolloff, "restored scrolloff")
  table.remove(runtime.scheduled, 1)()
  t.assert_eq(2, runtime.view.lnum, "cursor after stale animation callback")
end)

t:test("final frame keeps the scrolled view and restores the target cursor", function()
  local runtime = setup()
  runtime.view = { lnum = 120, col = 3, coladd = 0, curswant = 7, topline = 100, topfill = 0, leftcol = 0, skipcol = 0 }
  runtime.check_scroll(1)

  local scrolled =
    { lnum = 101, col = 0, coladd = 0, curswant = 0, topline = 100, topfill = 0, leftcol = 0, skipcol = 0 }
  local result = finish_animation(runtime, scrolled)

  t.assert_eq(0, #result.restores, "view restores")
  t.assert_eq("120:4:0:8", table.concat(result.cursor or {}, ":"), "target cursor")
  t.assert_eq("", result.virtualedit, "virtualedit before cursor restore")
  t.assert_eq(4, runtime.options.scrolloff, "restored scrolloff")
end)

t:test("final frame restores an end-of-line curswant with the target view", function()
  local runtime = setup()
  runtime.view = {
    lnum = 120,
    col = 3,
    coladd = 0,
    curswant = vim.v.maxcol,
    topline = 100,
    topfill = 0,
    leftcol = 0,
    skipcol = 0,
  }
  runtime.check_scroll(1)

  local scrolled =
    { lnum = 101, col = 0, coladd = 0, curswant = 0, topline = 100, topfill = 0, leftcol = 0, skipcol = 0 }
  local result = finish_animation(runtime, scrolled)

  t.assert_eq(1, #result.restores, "view restores")
  t.assert_eq(vim.v.maxcol, result.restores[1].curswant, "restored curswant")
  t.assert_eq("", result.virtualedit, "virtualedit before view restore")
  t.assert_nil(result.cursor, "cursor-only restore")
end)

t:test("final frame restores the target view when scrolling falls short", function()
  local runtime = setup()
  runtime.view = { lnum = 120, col = 3, coladd = 0, curswant = 7, topline = 100, topfill = 0, leftcol = 0, skipcol = 0 }
  runtime.check_scroll(1)

  local scrolled =
    { lnum = 101, col = 0, coladd = 0, curswant = 0, topline = 99, topfill = 0, leftcol = 0, skipcol = 0 }
  local result = finish_animation(runtime, scrolled)

  t.assert_eq(1, #result.restores, "view restores")
  t.assert_eq(100, result.restores[1].topline, "restored topline")
  t.assert_eq(120, result.restores[1].lnum, "restored cursor line")
  t.assert_nil(result.cursor, "cursor-only restore")
end)

t:test("animates while a float is visible", function()
  local runtime = setup()
  runtime.float = true

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)

  t.assert_eq(1, #runtime.timers, "animation timers")
end)

t:test("a scroll inside a key sequence animates once the whole sequence has run", function()
  local runtime = setup()
  local state = "m" ---@type string
  t:patch_table(vim.fn, "state", function()
    return state
  end)
  t:patch_table(vim, "v", { event = { ["1"] = { topline = 99 } } })

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.autocmds.WinScrolled.callback()
  t.assert_eq(0, #runtime.timers, "no animation while keys are pending")

  runtime.view.lnum = 120
  runtime.view.topline = 110
  state = ""
  runtime.autocmds.SafeState.callback()
  t.assert_eq(1, #runtime.timers, "animation once the sequence has run")
  t.assert_eq(110, runtime.states[1].target.topline, "final view of the sequence")
  t.assert_eq(1, runtime.states[1].current.topline, "view before the sequence")

  runtime.autocmds.SafeState.callback()
  t.assert_eq(1, #runtime.timers, "one check per pending window")
end)

t:test("a scroll beyond one screen animates all the way from its start", function()
  local runtime = setup()
  runtime.height = 50
  local target = { lnum = 300, col = 0, coladd = 0, curswant = 0, topline = 300, topfill = 0, leftcol = 0, skipcol = 0 }
  runtime.view = vim.deepcopy(target)
  runtime.check_scroll(1)

  t.assert_eq(1, #runtime.timers, "animation timers")
  t.assert_eq(1, runtime.states[1].current.topline, "animation start")
  t.assert_eq(300, runtime.states[1].target.topline, "animation target")

  local scrolled = 0 ---@type integer
  for _, command in ipairs(finish_animation(runtime, target).commands) do
    scrolled = scrolled + (tonumber(command:match("normal! (%d+)\5")) or 0)
  end
  t.assert_eq(299, scrolled, "lines scrolled by the frames")
end)

t:test("a frame keeps the cursor off the part of a smoothscroll topline its view skips", function()
  local runtime = setup()
  runtime.heights[5] = 24
  runtime.view = { lnum = 35, col = 0, coladd = 0, curswant = 0, topline = 30, topfill = 0, leftcol = 0, skipcol = 0 }
  runtime.Scroll.accept_current_view(1)
  -- The target puts the cursor on the topline, so the last frame moves it to the first window line.
  local target = { lnum = 6, col = 0, coladd = 0, curswant = 0, topline = 6, topfill = 0, leftcol = 0, skipcol = 0 }
  runtime.view = vim.deepcopy(target)
  runtime.check_scroll(1)
  local skipped = { lnum = 8, col = 0, coladd = 0, curswant = 0, topline = 6, topfill = 0, leftcol = 0, skipcol = 960 }
  local commands = finish_animation(runtime, skipped).commands

  t.assert_true(vim.deep_equal({ 6, 960 }, runtime.cursors[#runtime.cursors]), vim.inspect(runtime.cursors))
  for _, command in ipairs(commands) do
    t.assert_nil(command:match("normal! 1H"), "H onto the skipped topline: " .. command)
  end
end)

t:test("a frame restores the count without scrolling sideways or the motion to the first column", function()
  local ignore = vim.keycode("<Ignore>")
  for _, count in ipairs({ 0, 3 }) do
    local runtime = setup()
    local v, reads = vim.v, 0
    -- Each frame reads the count before its commands, which leave a count of 2, and after them.
    t:patch_table(
      vim,
      "v",
      setmetatable({}, {
        __index = function(_, key)
          if key == "count" then
            reads = reads + 1
            return reads % 2 == 1 and count or 2
          end
          return v[key]
        end,
      })
    )
    runtime.view.lnum = 100
    runtime.view.topline = 100
    runtime.check_scroll(1)
    local commands = finish_animation(runtime, vim.deepcopy(runtime.view)).commands

    local restore = "keepjumps normal! " .. (count > 0 and count or "") .. ignore
    t.assert_true(vim.list_contains(commands, restore), vim.inspect(commands))
    for _, command in ipairs(commands) do
      t.assert_nil(command:match("normal! 0"), "a count of 0 runs the 0 motion: " .. command)
      t.assert_nil(command:match("z[hl]"), "a frame scrolls a nowrap window sideways: " .. command)
    end
  end
end)

t:test("scrolling between parts of a wrapped line animates only the screen lines in between", function()
  local runtime = setup()
  -- Line 6 wraps into 24 screen lines; the views start or stop 12 screen lines into it.
  runtime.heights[5] = 24
  local into = { lnum = 6, col = 0, coladd = 0, curswant = 0, topline = 6, topfill = 0, leftcol = 0, skipcol = 960 }
  local below = { lnum = 9, col = 0, coladd = 0, curswant = 0, topline = 9, topfill = 0, leftcol = 0, skipcol = 0 }
  for _, case in ipairs({
    { from = below, to = into, key = "\25", lines = 14, name = "up into the wrapped line" },
    { from = runtime.view, to = into, key = "\5", lines = 17, name = "down into the wrapped line" },
    { from = into, to = below, key = "\5", lines = 14, name = "down out of the wrapped line" },
  }) do
    runtime.view = vim.deepcopy(case.from)
    runtime.Scroll.accept_current_view(1)
    runtime.view = vim.deepcopy(case.to)
    runtime.check_scroll(1)
    local scrolled = 0 ---@type integer
    for _, command in ipairs(finish_animation(runtime, case.to).commands) do
      scrolled = scrolled + (tonumber(command:match("normal! (%d+)" .. case.key)) or 0)
    end
    t.assert_eq(case.lines, scrolled, case.name)
  end
end)

t:test("a float appearing mid-animation leaves it running", function()
  local runtime = setup()
  runtime.view = { lnum = 120, col = 3, coladd = 0, curswant = 7, topline = 100, topfill = 0, leftcol = 0, skipcol = 0 }
  runtime.check_scroll(1)
  local timer = runtime.timers[1]
  t:patch_table(vim, "cmd", function() end)

  assert(timer.callback)()
  table.remove(runtime.scheduled, 1)()
  t.assert_true(runtime.states[1].timer == timer, "animation continues without a float")

  runtime.float = true
  runtime.view = { lnum = 101, col = 0, coladd = 0, curswant = 0, topline = 100, topfill = 0, leftcol = 0, skipcol = 0 }
  assert(timer.callback)()
  table.remove(runtime.scheduled, 1)()
  t.assert_true(runtime.states[1].timer == timer, "animation continues under a float")
end)

t:test("an oversized scroll during an animation restarts it and keeps the new target curswant", function()
  local runtime = setup()
  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)
  local first = runtime.timers[1]

  runtime.height = 50
  local target =
    { lnum = 900, col = 5, coladd = 0, curswant = 30, topline = 880, topfill = 0, leftcol = 0, skipcol = 0 }
  runtime.view = vim.deepcopy(target)
  runtime.check_scroll(1)

  t.assert_true(first.cleared, "previous animation stopped")
  t.assert_eq(2, #runtime.timers, "animation timers")
  t.assert_eq(1, runtime.states[1].current.topline, "animation start")
  t.assert_eq(30, runtime.states[1].target.curswant, "target curswant")
  local result = finish_animation(runtime, target)
  t.assert_eq("900:6:0:31", table.concat(result.cursor or {}, ":"), "target cursor and curswant")
  t.assert_eq("", result.virtualedit, "restored virtualedit")
end)

t:test("a typed key first finishes running animations on their targets", function()
  local runtime = setup()
  runtime.view = { lnum = 120, col = 3, coladd = 0, curswant = 7, topline = 100, topfill = 0, leftcol = 0, skipcol = 0 }
  runtime.check_scroll(1)
  local timer = runtime.timers[1]
  local restored = nil ---@type { view: vim.fn.winsaveview.ret, virtualedit: string }|nil
  t:patch_table(vim.fn, "winrestview", function(view)
    restored = { view = view, virtualedit = runtime.options.virtualedit }
    runtime.view = vim.deepcopy(view)
  end)

  assert(runtime.on_key)("x", "x")

  local restore = assert(restored, "target view restored")
  t.assert_true(timer.cleared, "timer cleared")
  t.assert_nil(runtime.states[1].timer, "active timer")
  t.assert_eq(4, runtime.options.scrolloff, "restored scrolloff")
  t.assert_eq("", restore.virtualedit, "virtualedit before the view restore")
  t.assert_eq(
    "120:3:7:100",
    ("%d:%d:%d:%d"):format(restore.view.lnum, restore.view.col, restore.view.curswant, restore.view.topline),
    "target view"
  )
  t.assert_eq(100, runtime.states[1].current.topline, "current topline")
end)

t:test("keys of the frames, a moving mouse and wheels leave animations running", function()
  local runtime = setup()
  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)
  local timer = runtime.timers[1]
  local on_key = assert(runtime.on_key)

  on_key("\5", "")
  for _, key in ipairs({ "<MouseMove>", "<ScrollWheelDown>" }) do
    on_key(vim.keycode(key), vim.keycode(key))
  end

  t.assert_false(timer.cleared, "timer cleared")
  t.assert_true(runtime.states[1].timer == timer, "active timer")
end)

t:test("a click stops animations on the view drawn under it", function()
  for _, key in ipairs({ "<LeftMouse>", "<2-LeftMouse>", "<RightMouse>", "<LeftDrag>", "<LeftRelease>" }) do
    local runtime = setup()
    runtime.view.lnum = 100
    runtime.view.topline = 100
    runtime.check_scroll(1)
    local timer = runtime.timers[1]
    -- A frame has drawn the window halfway to its target.
    runtime.view = { lnum = 50, col = 0, coladd = 0, curswant = 0, topline = 40, topfill = 0, leftcol = 0, skipcol = 0 }
    assert(runtime.on_key)(vim.keycode(key), vim.keycode(key))

    t.assert_true(timer.cleared, key .. " clears the timer")
    t.assert_nil(runtime.states[1].timer, key .. " ends the animation")
    t.assert_eq(40, runtime.states[1].current.topline, key .. " keeps the drawn view")
    t.assert_eq(40, runtime.view.topline, key .. " does not restore the target view")
    t.assert_eq(4, runtime.options.scrolloff, key .. " restores scrolloff")
  end
end)

t:test("Select mode scrolls directly without touching the view", function()
  local runtime = setup()
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "s", blocking = false }
  end)
  local restores = 0 ---@type integer
  t:patch_table(vim.fn, "winrestview", function(view)
    restores = restores + 1
    runtime.view = vim.deepcopy(view)
  end)

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)

  t.assert_eq(0, #runtime.timers, "animation timers")
  t.assert_eq(0, restores, "view restores")
  t.assert_eq(100, runtime.states[1].current.topline, "current topline")
end)

t:test("scrollbind windows scroll directly", function()
  local runtime = setup()
  runtime.options.scrollbind = true

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)

  t.assert_eq(0, #runtime.timers, "animation timers")
  t.assert_eq(100, runtime.states[1].current.topline, "current topline")
end)

t:test("Select mode entered during an animation stops it before a frame runs keys", function()
  local runtime = setup()
  runtime.view = { lnum = 120, col = 3, coladd = 0, curswant = 7, topline = 100, topfill = 0, leftcol = 0, skipcol = 0 }
  runtime.check_scroll(1)
  local timer = runtime.timers[1]
  local commands = {} ---@type string[]
  t:patch_table(vim, "cmd", function(command)
    commands[#commands + 1] = command
  end)
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "s", blocking = false }
  end)

  assert(timer.callback)()
  table.remove(runtime.scheduled, 1)()

  t.assert_eq(0, #commands, "frame commands")
  t.assert_nil(runtime.states[1].timer, "active timer")
  t.assert_eq("", runtime.options.virtualedit, "restored virtualedit")
  t.assert_eq(4, runtime.options.scrolloff, "restored scrolloff")
end)

t:test("a buffer leaving its window finishes the animation and restores the window options", function()
  local runtime = setup()
  runtime.view = { lnum = 120, col = 3, coladd = 0, curswant = 7, topline = 100, topfill = 0, leftcol = 0, skipcol = 0 }
  runtime.check_scroll(1)
  local timer = runtime.timers[1]
  local restored = nil ---@type vim.fn.winsaveview.ret|nil
  t:patch_table(vim.fn, "winrestview", function(view)
    restored = view
    runtime.view = vim.deepcopy(view)
  end)

  runtime.autocmds.BufLeave.callback({ buf = 2 })
  t.assert_false(timer.cleared, "another buffer leaves the animation running")

  runtime.autocmds.BufLeave.callback({ buf = 1 })
  t.assert_true(timer.cleared, "timer cleared")
  t.assert_eq("", runtime.options.virtualedit, "restored virtualedit")
  t.assert_eq(4, runtime.options.scrolloff, "restored scrolloff")
  t.assert_eq(100, assert(restored, "target view restored").topline, "target topline")
end)

t:test("a wheel that scrolled nothing leaves the next scroll animated", function()
  local runtime = setup()
  local wheel = vim.keycode("<ScrollWheelUp>")
  assert(runtime.on_key)(wheel, wheel)
  runtime.autocmds.SafeState.callback()

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)

  t.assert_eq(1, #runtime.timers, "animation timers")
end)

t:test("a mapped wheel scrolls directly", function()
  local runtime = setup()
  assert(runtime.on_key)("\5", vim.keycode("<ScrollWheelDown>"))

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)

  t.assert_eq(0, #runtime.timers, "animation timers")
  t.assert_eq(100, runtime.states[1].current.topline, "current topline")
end)

t:test("closing a window releases its animation state", function()
  local runtime = setup()
  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)
  local timer = runtime.timers[1]

  runtime.autocmds.WinClosed.callback({ match = "1" })

  t.assert_true(timer.cleared, "timer cleared")
  t.assert_nil(runtime.get_states()[1], "window state")
end)

t:test("accepts a programmatic view change as the new baseline", function()
  local runtime = setup()

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.Scroll.accept_current_view(1)
  runtime.check_scroll(1)

  t.assert_eq(0, #runtime.timers, "animation timers")
  t.assert_eq(100, runtime.states[1].current.topline, "current topline")
  t.assert_eq(100, runtime.states[1].target.topline, "target topline")
  t.assert_eq(0, runtime.states[1].last, "repeat timestamp")
end)

t:test("cancels active animation and invalidates its queued callback", function()
  local runtime = setup()

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)

  local timer = runtime.timers[1]
  assert(timer.callback)()
  t.assert_eq(1, #runtime.scheduled, "queued timer callbacks")
  t.assert_eq("all", runtime.options.virtualedit, "animation virtualedit")
  t.assert_eq(0, runtime.options.scrolloff, "animation scrolloff")

  runtime.view.lnum = 50
  runtime.view.topline = 50
  runtime.Scroll.accept_current_view(1)

  t.assert_true(timer.cleared, "timer cleared")
  t.assert_nil(runtime.states[1].timer, "active timer")
  t.assert_eq("", runtime.options.virtualedit, "restored virtualedit")
  t.assert_eq(4, runtime.options.scrolloff, "restored scrolloff")
  t.assert_eq(50, runtime.states[1].current.topline, "accepted topline")

  table.remove(runtime.scheduled, 1)()
  t.assert_eq(50, runtime.view.topline, "view after stale callback")
end)

t:test("is a safe no-op while disabled", function()
  local runtime = setup()

  runtime.enabled = false
  runtime.observer()
  runtime.view.topline = 20
  runtime.Scroll.accept_current_view(1)

  t.assert_nil(runtime.get_states()[1], "window state")
  t.assert_eq(0, #runtime.timers, "animation timers")
end)

t:test("is a safe no-op for an invalid window", function()
  local runtime = setup()

  runtime.view.topline = 20
  runtime.valid = false
  runtime.Scroll.accept_current_view(1)

  t.assert_eq(1, runtime.states[1].current.topline, "current topline")
  t.assert_eq(0, #runtime.timers, "animation timers")
end)

t:test("replaces stale state when a window starts displaying another buffer", function()
  local runtime = setup()

  runtime.bufnr = 2
  runtime.view.lnum = 30
  runtime.view.topline = 30
  runtime.Scroll.accept_current_view(1)

  local state = runtime.get_states()[1]
  t.assert_eq(2, state.bufnr, "state buffer")
  t.assert_eq(30, state.current.topline, "current topline")
  t.assert_eq(0, #runtime.timers, "animation timers")
end)

t:run()
