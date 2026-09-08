---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.nvimbar.notification" ---@type string

local t = require("__test__.support.harness").new("era.m.nvimbar.notification")
local bootstrap = require("__test__.support.bootstrap")
local clock_fixture = require("__test__.fixtures.era.m.nvimbar.clock")
local Future = require("stl.c.future")

bootstrap.with_runtime(t, {
  stl = {
    fn = { noop = function() end },
    nvim = { fn = {
      txt = function(text)
        return text
      end,
    } },
    reporter = {
      error = function(details)
        error(vim.inspect(details))
      end,
    },
  },
  dot = {
    path = {
      cwd = function()
        return "/test"
      end,
    },
    theme = { hlgroup = { common = {
      resolve_mode = function()
        return "n", "NORMAL"
      end,
    } } },
  },
  yoz = { path = {
    basename = function(path)
      return path:match("[^/]*$")
    end,
  } },
})

---@param value                         integer
---@param bufnr                         ?integer
---@return era.m.nvimbar.INvimbarContext
local function context(value, bufnr)
  return {
    winnr = 10,
    bufnr = bufnr or 20,
    tabnr = 30,
    cwd = "/test",
    filename = "test.lua",
    filepath = "test.lua",
    filetype = "lua",
    mode = "n",
    mode_name = "NORMAL",
    cursor = { 1, 0 },
    line_count = 1,
    changedtick = value,
  }
end

---@param policy                        ?era.m.nvimbar.INotifyPolicy
---@return era.m.nvimbar.IRawComponent
local function definition(policy)
  return {
    name = "test",
    notify = policy,
    refresh = function(ctx)
      local text = tostring(ctx.changedtick)
      return { text = text, hltext = text }
    end,
  }
end

---@param clock                         __test__.fixtures.nvimbar.IClock
---@param source                        era.m.nvimbar.IComponentSource
---@param override                      ?era.m.nvimbar.INotifyPolicy
---@return era.m.nvimbar.Component
---@return { at: number, context: era.m.nvimbar.INvimbarContext }[]
local function component(clock, source, override)
  local seen = {}
  local runtime = clock.Component.new(source, function(ctx)
    seen[#seen + 1] = { at = clock.now, context = ctx }
  end, function()
    return true
  end, nil, override)
  t:defer(function()
    runtime:dispose()
  end)
  return runtime, seen
end

---@return integer
local function window()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 1, col = 1, width = 30, height = 3 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  return winnr
end

---@param clock                         __test__.fixtures.nvimbar.IClock
---@param winnr                         integer
---@param interval                      ?integer
---@return era.m.nvimbar.Nvimbar
---@return { at: number, text: string }[]
---@return fun(): integer
local function bar(clock, winnr, interval)
  local seen, layouts = {}, 0
  local result = clock.Nvimbar.new({
    name = "test",
    comp_sep = "",
    comp_sep_hlname = "Normal",
    comp_sep_hlname_active = "Normal",
    get_preset_context = function()
      return { winnr = winnr }
    end,
    get_max_width = function()
      layouts = layouts + 1
      return 20
    end,
    is_active = function()
      return true
    end,
    on_fulfilled = function(text)
      seen[#seen + 1] = { at = clock.now, text = text }
    end,
    draw_interval = interval,
  })
  t:defer(function()
    result:dispose()
  end)
  return result, seen, function()
    return layouts
  end
end

t:test("immediate notifications follow each committed snapshot", function()
  local clock = clock_fixture.new(t)
  local runtime, seen = component(clock, definition())
  runtime:request(context(1))
  clock:advance(1)
  t.assert_eq(1, #seen)
  runtime:request(context(2))
  clock:advance(2)
  t.assert_eq(2, #seen)
  t.assert_eq(2, seen[2].context.changedtick)
end)

t:test("debounce delays notification without delaying data acquisition", function()
  local clock = clock_fixture.new(t)
  local runtime, seen = component(clock, definition({ strategy = "debounce", interval = 10 }))
  runtime:request(context(1))
  clock:advance(1)
  t.assert_eq("ready", runtime.status)
  t.assert_eq("1", runtime:format(context(1), 20))
  t.assert_eq(0, #seen)
  clock:advance(5)
  runtime:request(context(2))
  clock:advance(6)
  t.assert_eq("2", runtime:format(context(2), 20))
  clock:advance(11)
  t.assert_eq(0, #seen, "the previous deadline was replaced")
  clock:advance(16)
  t.assert_eq(1, #seen)
  t.assert_eq(2, seen[1].context.changedtick)
  clock:advance(100)
  t.assert_eq(1, #seen, "no background notifications after the trailing edge")
end)

t:test("throttle delivers a leading edge and the latest trailing edge without postponement", function()
  local clock = clock_fixture.new(t)
  local runtime, seen = component(clock, definition({ strategy = "throttle", interval = 10 }))
  runtime:request(context(1))
  clock:advance(1)
  t.assert_eq(1, #seen)
  clock:advance(3)
  runtime:request(context(2))
  clock:advance(4)
  clock:advance(5)
  runtime:request(context(3))
  clock:advance(6)
  t.assert_eq(1, #seen)
  clock:advance(11)
  t.assert_eq(2, #seen)
  t.assert_eq(3, seen[2].context.changedtick)
  t.assert_eq(11, seen[2].at)
  runtime:request(context(4))
  clock:advance(12)
  clock:advance(21)
  t.assert_eq(3, #seen, "the final change is delivered without another request")
  t.assert_eq(4, seen[3].context.changedtick)
end)

t:test("lazy defaults and explicit replacement policies are captured independently", function()
  local clock = clock_fixture.new(t)
  local constructions = 0
  local source = function()
    constructions = constructions + 1
    return definition({ strategy = "debounce", interval = 20 })
  end
  local delayed, delayed_seen = component(clock, source)
  local override = { strategy = "throttle", interval = 5 } ---@type era.m.nvimbar.INotifyPolicy
  local replaced, replaced_seen = component(clock, source, override)
  override.interval = 100
  delayed:request(context(1))
  replaced:request(context(1))
  clock:advance(1)
  clock:advance(2)
  t.assert_eq(2, constructions)
  t.assert_eq(0, #delayed_seen)
  t.assert_eq(1, #replaced_seen)
  replaced:request(context(2))
  clock:advance(3)
  clock:advance(7)
  t.assert_eq(2, #replaced_seen, "placement captured its own interval")
  clock:advance(21)
  t.assert_eq(1, #delayed_seen)
  t.assert_eq(2, constructions, "notification does not reconstruct providers")
end)

t:test("scope changes cancel old notifications and start a new throttle window", function()
  local clock = clock_fixture.new(t)
  local runtime, seen = component(clock, definition({ strategy = "throttle", interval = 10 }))
  runtime:request(context(1, 20))
  clock:advance(1)
  runtime:request(context(2, 20))
  clock:advance(2)
  runtime:request(context(3, 21))
  clock:advance(3)
  t.assert_eq(2, #seen)
  t.assert_eq(21, seen[2].context.bufnr)
  clock:advance(11)
  t.assert_eq(2, #seen, "the previous owner's trailing edge was cancelled")
end)

t:test("cancel and dispose suppress pending notifications", function()
  local clock = clock_fixture.new(t)
  local runtime, seen = component(clock, definition({ strategy = "debounce", interval = 10 }))
  runtime:request(context(1))
  clock:advance(1)
  runtime:cancel()
  clock:advance(11)
  t.assert_eq(0, #seen)
  runtime:request(context(2))
  clock:advance(12)
  runtime:dispose()
  clock:advance(22)
  t.assert_eq(0, #seen)
end)

t:test("will_change failures and retries retain the notification throttle window", function()
  local clock = clock_fixture.new(t)
  local reports = {}
  t:patch_table(stl.reporter, "error", function(report)
    reports[#reports + 1] = report
  end)
  local source = definition({ strategy = "throttle", interval = 10 })
  source.will_change = function(ctx, prev_context)
    if ctx.changedtick > 1 then
      error("transient change check failure")
    end
    return ctx.changedtick ~= prev_context.changedtick
  end
  local runtime, seen = component(clock, source)
  runtime:request(context(1))
  clock:advance(1)
  clock:advance(2)
  runtime:request(context(2))
  t.assert_eq("failed", runtime.status)
  clock:advance(3)
  runtime:request(context(3))
  clock:advance(4)
  t.assert_eq("ready", runtime.status)
  t.assert_eq(1, #reports)
  t.assert_eq(1, #seen, "errors do not create another leading edge")
  clock:advance(11)
  t.assert_eq(2, #seen)
  t.assert_eq(3, seen[2].context.changedtick)
end)

t:test("pending notifications retain committed context while a newer request is running", function()
  local clock = clock_fixture.new(t)
  local source = definition({ strategy = "throttle", interval = 10 })
  local refresh = source.refresh
  local resolve
  source.refresh = function(ctx, token)
    if ctx.changedtick < 3 then
      return refresh(ctx, token)
    end
    local future
    future, resolve = Future.new_with_resolver({ token = token })
    return future
  end
  local runtime, seen = component(clock, source)
  runtime:request(context(1))
  clock:advance(1)
  runtime:request(context(2))
  clock:advance(2)
  runtime:request(context(3))
  clock:advance(3)
  t.assert_eq("running", runtime.status)
  clock:advance(11)
  t.assert_eq(2, seen[2].context.changedtick, "notification describes completed data")
  resolve({ text = "3", hltext = "3" })
  clock:advance(21)
  t.assert_eq(3, seen[3].context.changedtick)
end)

t:test("invalid policies are rejected before a placement changes the bar", function()
  local clock = clock_fixture.new(t)
  local target = bar(clock, window())
  local refreshes = 0
  local source = definition()
  source.refresh = function()
    refreshes = refreshes + 1
  end
  ---@type any[]
  local invalid = {
    false,
    {},
    { strategy = "later" },
    { strategy = "throttle" },
    { strategy = "debounce", interval = 0 },
    { strategy = "immediate", interval = 10 },
  }
  for _, policy in ipairs(invalid) do
    local placement = { position = "left", component = source, notify = policy } ---@type any
    local ok = pcall(target.place, target, placement)
    t.assert_false(ok)
  end
  target:refresh()
  clock:advance(1)
  clock:advance(2)
  t.assert_eq(0, refreshes, "invalid placements did not install a provider")
end)

t:test("bar publications have a fixed trailing deadline and include the latest snapshot", function()
  local clock = clock_fixture.new(t)
  local target, seen, layouts = bar(clock, window())
  local value = "A"
  target:place({
    position = "left",
    component = {
      name = "value",
      refresh = function()
        return { text = value, hltext = value }
      end,
    },
  })
  target:refresh()
  clock:advance(0)
  clock:advance(1)
  clock:advance(1)
  t.assert_true(target:snapshot():find("A", 1, true))
  local before = layouts()
  value = "B"
  target:refresh()
  clock:advance(2)
  value = "C"
  target:refresh()
  clock:advance(3)
  clock:advance(16)
  t.assert_eq(before, layouts(), "requests and completions do not each lay out the bar")
  clock:advance(17)
  t.assert_eq(before + 1, layouts())
  t.assert_true(target:snapshot():find("C", 1, true))
  t.assert_eq(17, seen[#seen].at)
  t.assert_eq(1, clock.timers)
end)

t:test("placement overrides reach forks and a component wakes only its own bar", function()
  local clock = clock_fixture.new(t)
  local first = bar(clock, window(), 0)
  local second, second_seen = bar(clock, window(), 0)
  ---@type era.m.nvimbar.IRawComponent
  local source = {
    name = "value",
    notify = { strategy = "debounce", interval = 100 },
    refresh = function()
      return { text = "READY", hltext = "READY" }
    end,
  }
  first:place({ position = "left", component = source, notify = { strategy = "immediate" } })
  local fork = first:fork(window())
  local seen = {}
  t:patch_table(fork, "_on_fulfilled", function(text)
    seen[#seen + 1] = text
  end)
  first:refresh()
  clock:advance(0)
  clock:advance(1)
  clock:advance(1)
  clock:advance(2)
  clock:advance(2)
  t.assert_true(first:snapshot():find("READY", 1, true))
  t.assert_true(fork:snapshot():find("READY", 1, true))
  t.assert_true(#seen > 0)
  t.assert_eq("", second:snapshot())
  t.assert_eq(0, #second_seen)
end)

t:test("a delayed notification revalidates its window owner before publication", function()
  local clock = clock_fixture.new(t)
  local winnr = window()
  local target, seen = bar(clock, winnr, 0)
  target:place({
    position = "left",
    component = {
      name = "buffer",
      notify = { strategy = "debounce", interval = 10 },
      refresh = function(ctx)
        local text = tostring(ctx.bufnr)
        return { text = text, hltext = text }
      end,
    },
  })
  target:refresh()
  clock:advance(0)
  clock:advance(1)
  local other = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(other) then
      vim.api.nvim_buf_delete(other, { force = true })
    end
  end)
  vim.api.nvim_win_set_buf(winnr, other)
  clock:advance(11)
  clock:advance(12)
  clock:advance(12)
  clock:advance(22)
  clock:advance(22)
  t.assert_true(target:snapshot():find(tostring(other), 1, true), "new owner is refreshed without another dirty event")
  t.assert_eq(target:snapshot(), seen[#seen].text)
end)

t:test("disposing a bar cancels its delayed publication", function()
  local clock = clock_fixture.new(t)
  local target, seen = bar(clock, window(), 20)
  target:refresh()
  clock:advance(0)
  local before = #seen
  target:refresh()
  target:dispose()
  clock:advance(20)
  clock:advance(40)
  t.assert_eq(before, #seen)
end)

t:run()
