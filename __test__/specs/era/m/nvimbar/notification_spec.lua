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

for _, throttled in ipairs({ false, true }) do
  t:test("latest scope publishes after its work when " .. (throttled and "throttled" or "queued"), function()
    local clock = clock_fixture.new(t)
    local first, second, third = window(), window(), window()
    local current = first
    local target, seen = bar(clock, first)
    t:patch_table(target, "_get_preset_context", function()
      return { winnr = current }
    end)
    target:place({
      position = "left",
      component = {
        name = "scope",
        refresh = function(ctx)
          -- Leave publication queued so a newer scope can request work in the next turn.
          if not throttled and ctx.winnr == second then
            clock.now = clock.now + 2
          end
          local text = ctx.winnr == first and "FIRST" or ctx.winnr == second and "SECOND" or "THIRD"
          return { text = text, hltext = text }
        end,
      },
    })
    target:refresh()
    clock:advance(1)
    clock:advance(1)
    t.assert_eq("FIRST%=", target:snapshot())
    local before = #seen
    clock:advance(throttled and 15 or 20)
    current = second
    target:refresh()
    clock:advance(throttled and 16 or 21)
    current = third
    target:refresh()
    clock:advance(throttled and 17 or 24)
    clock:advance(clock.now)
    t.assert_eq("THIRD%=", target:snapshot())
    for i = before + 1, #seen do
      t.assert_true(seen[i].text ~= "%=", "scope change emitted an empty frame")
    end
  end)
end

for _, interval in ipairs({ 16, 200 }) do
  t:test("retry after initial cancellation publishes ready content before the " .. interval .. "ms deadline", function()
    local clock = clock_fixture.new(t)
    local target, seen = bar(clock, window(), interval)
    local refreshes = 0
    target:place({
      position = "left",
      component = {
        name = "retry",
        refresh = function()
          refreshes = refreshes + 1
          return { text = "READY", hltext = "READY" }
        end,
      },
    })
    target:refresh()
    target:cancel_refresh()
    clock:advance(0)
    t.assert_eq(0, refreshes, "the cancelled request never runs")
    clock:advance(1)
    target:refresh()
    clock:advance(2)
    clock:advance(2)
    t.assert_eq(1, refreshes)
    t.assert_eq("READY%=", target:snapshot())
    t.assert_eq(2, seen[#seen].at, "cancellation must not consume the first-result publication")
  end)
end

t:test("queued publication does not wait for an unresolved provider", function()
  local clock = clock_fixture.new(t)
  local target, seen = bar(clock, window())
  local resolve
  target:place({
    position = "left",
    component = {
      name = "async",
      refresh = function()
        local future
        future, resolve = Future.new_with_resolver()
        return future
      end,
    },
  })
  target:refresh()
  clock:advance(0)
  t.assert_eq(0, #seen, "publication follows the queued provider call")
  clock:advance(1)
  clock:advance(2)
  t.assert_eq("%=", seen[1].text, "pending I/O does not keep another owner's frame")
  resolve({ text = "READY", hltext = "READY" })
  clock:advance(2)
  t.assert_eq("READY%=", target:snapshot())
end)

t:test("a refresh burst publishes the latest data once", function()
  local clock = clock_fixture.new(t)
  local target, seen = bar(clock, window(), 0)
  local value, refreshes = "INITIAL", 0
  target:place({
    position = "left",
    component = {
      name = "burst",
      refresh = function()
        refreshes = refreshes + 1
        return { text = value, hltext = value }
      end,
    },
  })
  target:refresh()
  clock:advance(1)
  clock:advance(1)
  local before = #seen
  for index = 1, 20 do
    value = tostring(index)
    target:refresh()
  end
  clock:advance(2)
  clock:advance(2)
  t.assert_eq("20%=", target:snapshot())
  t.assert_eq(2, refreshes, "only the latest queued request reaches the provider")
  t.assert_eq(before + 1, #seen, "discarded publication jobs do not consume additional turns")
end)

t:test("a window change after data completion refreshes the owner before publication", function()
  local clock = clock_fixture.new(t)
  local first, second = window(), window()
  local current = first
  local target, seen = bar(clock, first)
  t:patch_table(target, "_get_preset_context", function()
    return { winnr = current }
  end)
  target:place({
    position = "left",
    component = {
      name = "owner",
      refresh = function(ctx)
        local text = ctx.winnr == first and "FIRST" or "SECOND"
        return { text = text, hltext = text }
      end,
    },
  })
  target:refresh()
  clock:advance(1)
  current = second
  clock:advance(1)
  clock:advance(2)
  clock:advance(2)
  t.assert_eq("SECOND%=", target:snapshot(), "publication must refresh a changed owner without another dirty event")
  for _, publication in ipairs(seen) do
    t.assert_eq("SECOND%=", publication.text, "obsolete publication must not clear or overwrite the target")
  end
end)

t:test("continuous same-scope refreshes cannot starve a queued publication", function()
  local clock = clock_fixture.new(t)
  local target, seen = bar(clock, window())
  local value = 0
  target:place({
    position = "left",
    component = {
      name = "busy",
      refresh = function()
        if value > 0 then
          clock.now = clock.now + 2
        end
        local text = tostring(value)
        return { text = text, hltext = text }
      end,
    },
  })
  target:refresh()
  clock:advance(1)
  clock:advance(1)
  local before = #seen
  clock:advance(20)
  for index = 1, 12 do
    value = index
    target:refresh()
    clock:advance(clock.now + 1)
    clock:advance(clock.now)
  end
  t.assert_true(#seen > before, "same-scope input must not keep moving publication behind newer work")
  clock:advance(100)
  clock:advance(100)
  t.assert_eq("12%=", target:snapshot())
end)

t:run()
