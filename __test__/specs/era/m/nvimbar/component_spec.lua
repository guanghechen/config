local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local Component = require("era.m.nvimbar.component")
local Future = require("stl.c.future")
local t = harness.new("era.m.nvimbar.component")

local errors = {}
bootstrap.with_runtime(t, {
  stl = { reporter = {
    error = function(error)
      errors[#errors + 1] = error
    end,
  } },
})

local function context(value, bufnr)
  return { winnr = 10, bufnr = bufnr or 20, tabnr = 30, filepath = "test.lua", cwd = "/test", value = value }
end

local function create(source, changed, is_current)
  local component = Component.new(source, changed or function() end, is_current or function()
    return true
  end)
  t:defer(function()
    component:dispose()
  end)
  return component
end

---@return nil
local function wait_status(component, status)
  t.wait_until(function()
    return component.status == status
  end, 1000, "component reaches " .. status)
end

t:test("factories and initial refresh run after the request returns", function()
  local constructed, refreshed = 0, 0
  local component = create(function()
    constructed = constructed + 1
    return {
      name = "lazy",

      refresh = function(ctx)
        refreshed = refreshed + 1
        return { text = ctx.value, hltext = ctx.value }
      end,
    }
  end)
  t.assert_eq("idle", component.status)
  component:request(context("first"))
  t.assert_eq("queued", component.status)
  t.assert_eq(0, constructed)
  t.assert_eq(0, refreshed)
  wait_status(component, "ready")
  t.assert_eq(1, constructed)
  t.assert_eq("first", component:format(context("first"), 20))
end)

t:test("queued requests collapse to the latest context", function()
  local seen = {}
  local component = create({
    name = "queue",

    refresh = function(ctx)
      seen[#seen + 1] = ctx.value
      return { text = ctx.value, hltext = ctx.value }
    end,
  })
  component:request(context("one"))
  component:request(context("two"))
  component:request(context("three"))
  wait_status(component, "ready")
  t.assert_true(vim.deep_equal({ "three" }, seen))
  t.assert_eq(3, component.snapshot.version)
end)

t:test("running requests reject stale results and rerun only the latest request", function()
  local jobs, published = {}, {}
  local component
  component = create({
    name = "latest",

    refresh = function(ctx, token)
      local future, resolve = Future.new_with_resolver({ token = token })
      jobs[#jobs + 1] = { value = ctx.value, resolve = resolve }
      return future
    end,
  }, function()
    if component.snapshot then
      published[#published + 1] = component.snapshot.data.text
    end
  end)
  component:request(context("one"))
  wait_status(component, "running")
  component:request(context("two"))
  component:request(context("three"))
  t.assert_eq(1, #jobs)
  jobs[1].resolve({ text = "one", hltext = "one" })
  t.wait_until(function()
    return #jobs == 2
  end, 1000)
  t.assert_eq("three", jobs[2].value)
  t.assert_true(vim.deep_equal({}, published))
  jobs[2].resolve({ text = "three", hltext = "three" })
  wait_status(component, "ready")
  t.assert_true(vim.deep_equal({ "three" }, published))
end)

t:test("a slow component does not hold another component's result", function()
  local resolve_slow
  local slow = create({
    name = "slow",

    refresh = function(_, token)
      local future, resolve = Future.new_with_resolver({ token = token })
      resolve_slow = resolve
      return future
    end,
  })
  local fast = create({
    name = "fast",

    refresh = function()
      return { text = "fast", hltext = "fast" }
    end,
  })
  slow:request(context())
  fast:request(context())
  wait_status(fast, "ready")
  t.assert_eq("running", slow.status)
  resolve_slow({ text = "slow", hltext = "slow" })
  wait_status(slow, "ready")
end)

t:test("same-context stale snapshots remain visible while foreign buffers cannot reuse them", function()
  local resolve_next
  local component = create({
    name = "cache",

    refresh = function(ctx, token)
      if ctx.value == "old" then
        return { text = "old", hltext = "old" }
      end
      local future, resolve = Future.new_with_resolver({ token = token })
      resolve_next = resolve
      return future
    end,
  })
  component:request(context("old"))
  wait_status(component, "ready")
  component:request(context("new"))
  wait_status(component, "running")
  t.assert_eq("old", component:format(context("new"), 20))
  t.assert_eq("", component:format(context("new", 21), 20))
  resolve_next({ text = "new", hltext = "new" })
  wait_status(component, "ready")
end)

t:test("will_change suppresses unrelated refreshes without suppressing explicit retries", function()
  local count = 0
  local component = create({
    name = "change check",

    will_change = function(ctx, prev_context)
      return ctx.filepath ~= prev_context.filepath
    end,
    refresh = function()
      count = count + 1
      return { text = "same", hltext = "same" }
    end,
  })
  component:request(context("cursor one"))
  wait_status(component, "ready")
  component:request(context("cursor two"))
  t.assert_eq("ready", component.status)
  t.assert_eq(1, count)
  component:request(context("cursor three"), true)
  wait_status(component, "ready")
  t.assert_eq(2, count)
end)

t:test("queued refreshes compare against the data actually acquired", function()
  local value, refreshes = "A", 0
  local component = create({
    name = "mutable data",
    will_change = function(_, _, snapshot)
      return value ~= snapshot.text
    end,
    refresh = function()
      refreshes = refreshes + 1
      return { text = value, hltext = value }
    end,
  })
  component:request(context())
  wait_status(component, "ready")
  value = "B"
  component:request(context())
  value = "C"
  wait_status(component, "ready")
  t.assert_eq("C", component:format(context(), 20))
  value = "B"
  component:request(context())
  wait_status(component, "ready")
  t.assert_eq("B", component:format(context(), 20), "a queued request cannot suppress a later change")
  component:request(context())
  t.assert_eq("ready", component.status)
  t.assert_eq(3, refreshes, "the acquired state remains reusable")
end)

t:test("Future completion preserves the data captured when acquisition started", function()
  local value, jobs = "A", {}
  local component = create({
    name = "async data",
    will_change = function(_, _, snapshot)
      return value ~= snapshot.text
    end,
    refresh = function(_, token)
      local future, resolve = Future.new_with_resolver({ token = token })
      jobs[#jobs + 1] = { value = value, resolve = resolve }
      return future
    end,
  })
  component:request(context())
  wait_status(component, "running")
  value = "B"
  jobs[1].resolve({ text = jobs[1].value, hltext = jobs[1].value })
  wait_status(component, "ready")
  t.assert_eq("A", component:format(context(), 20))
  component:request(context())
  t.wait_until(function()
    return #jobs == 2
  end, 1000)
  jobs[2].resolve({ text = jobs[2].value, hltext = jobs[2].value })
  wait_status(component, "ready")
  t.assert_eq("B", component:format(context(), 20), "completion cannot cache an unread state")
end)

t:test("repeated in-flight requests reuse the completed result without another refresh", function()
  local jobs, publications = {}, 0
  local component = create({
    name = "reuse pending result",
    will_change = function(ctx, prev_context, snapshot)
      t.assert_eq(prev_context.value, snapshot.text)
      return ctx.value ~= snapshot.text
    end,
    refresh = function(ctx, token)
      local future, resolve = Future.new_with_resolver({ token = token })
      jobs[#jobs + 1] = { value = ctx.value, resolve = resolve }
      return future
    end,
  }, function()
    publications = publications + 1
  end)
  component:request(context("same"))
  wait_status(component, "running")
  for _ = 1, 20 do
    component:request(context("same"))
  end
  jobs[1].resolve({ text = "same", hltext = "same" })
  t.assert_eq("ready", component.status)
  t.assert_eq(1, #jobs)
  t.assert_eq(1, publications)
  t.assert_eq(component.requested_version, component.snapshot.version)
  component:request(context("same"))
  t.assert_eq("ready", component.status)
  t.assert_eq(1, #jobs)
end)

t:test("changed dependencies discard the candidate and refresh only the latest context", function()
  local jobs, publications = {}, 0
  local component = create({
    name = "changed pending result",
    will_change = function(ctx, _, snapshot)
      return ctx.value ~= snapshot.text
    end,
    refresh = function(ctx, token)
      local future, resolve = Future.new_with_resolver({ token = token })
      jobs[#jobs + 1] = { value = ctx.value, resolve = resolve }
      return future
    end,
  }, function()
    publications = publications + 1
  end)
  component:request(context("old"))
  wait_status(component, "running")
  component:request(context("intermediate"))
  component:request(context("latest"))
  jobs[1].resolve({ text = "old", hltext = "old" })
  t.assert_nil(component.snapshot)
  t.assert_eq(0, publications)
  t.wait_until(function()
    return #jobs == 2
  end, 1000)
  t.assert_eq("latest", jobs[2].value)
  jobs[2].resolve({ text = "latest", hltext = "latest" })
  wait_status(component, "ready")
  t.assert_eq("latest", component:format(context(), 20))
  t.assert_eq(1, publications)
end)

t:test("returning to committed data cannot let an intervening request overwrite it", function()
  local resolve_next ---@type fun(data: any): nil
  local refreshes = 0
  local component = create({
    name = "return to snapshot",
    will_change = function(ctx, _, snapshot)
      return ctx.value ~= snapshot.text
    end,
    refresh = function(ctx, token)
      refreshes = refreshes + 1
      if ctx.value == "A" then
        return { text = "A", hltext = "A" }
      end
      local future
      future, resolve_next = Future.new_with_resolver({ token = token })
      return future
    end,
  })
  component:request(context("A"))
  wait_status(component, "ready")
  component:request(context("B"))
  wait_status(component, "running")
  component:request(context("A"))
  resolve_next({ text = "B", hltext = "B" })
  t.assert_eq("A", component:format(context(), 20))
  wait_status(component, "ready")
  t.assert_eq("A", component:format(context(), 20))
  t.assert_eq(3, refreshes)
end)

t:test("force requests bypass will_change and survive coalescing with ordinary requests", function()
  local jobs, checks = {}, 0
  local component = create({
    name = "forced pending refresh",
    will_change = function()
      checks = checks + 1
      return false
    end,
    refresh = function(_, token)
      local future, resolve = Future.new_with_resolver({ token = token })
      jobs[#jobs + 1] = resolve
      return future
    end,
  })
  component:request(context())
  wait_status(component, "running")
  component:request(context(), true)
  component:request(context())
  jobs[1]({ text = "old", hltext = "old" })
  t.assert_nil(component.snapshot)
  t.wait_until(function()
    return #jobs == 2
  end, 1000)
  jobs[2]({ text = "new", hltext = "new" })
  wait_status(component, "ready")
  t.assert_eq(0, checks)
  component:request(context(), true)
  t.wait_until(function()
    return #jobs == 3
  end, 1000)
  jobs[3]({ text = "forced", hltext = "forced" })
  wait_status(component, "ready")
  t.assert_eq(0, checks)
  t.assert_eq("forced", component:format(context(), 20))
end)

t:test("force requests from completion cleanup still require a new refresh", function()
  local component ---@type era.m.nvimbar.Component
  local jobs = {}
  component = create({
    name = "force during cleanup",
    will_change = function()
      return false
    end,
    refresh = function(_, token)
      local future, resolve = Future.new_with_resolver()
      jobs[#jobs + 1] = resolve
      if #jobs == 1 then
        token:on_cancel(function()
          component:request(context(), true)
        end)
      end
      return future
    end,
  })
  component:request(context())
  wait_status(component, "running")
  jobs[1]({ text = "old", hltext = "old" })
  t.assert_nil(component.snapshot)
  t.wait_until(function()
    return #jobs == 2
  end, 1000)
  jobs[2]({ text = "new", hltext = "new" })
  wait_status(component, "ready")
  t.assert_eq("new", component:format(context(), 20))
end)

t:test("scope changes and cancellation bypass a false will_change result", function()
  local checks, refreshes = 0, 0
  local component = create({
    name = "scope refresh",
    will_change = function()
      checks = checks + 1
      return false
    end,
    refresh = function()
      refreshes = refreshes + 1
      return { text = "ready", hltext = "ready" }
    end,
  })
  local ctx = context()
  component:request(ctx)
  wait_status(component, "ready")
  for _, field in ipairs({ "winnr", "bufnr", "tabnr", "filepath", "cwd" }) do
    ctx = vim.deepcopy(ctx)
    ctx[field] = type(ctx[field]) == "number" and ctx[field] + 1 or ctx[field] .. "/next"
    component:request(ctx)
    wait_status(component, "ready")
    t.assert_eq(ctx, component.snapshot.context)
  end
  component:cancel()
  component:request(ctx)
  wait_status(component, "ready")
  t.assert_eq(7, refreshes)
  t.assert_eq(0, checks)
end)

t:test("invalid will_change results preserve the snapshot and cannot block forced refreshes", function()
  for _, check in ipairs({
    function()
      error("check unavailable")
    end,
    function()
      return nil
    end,
    function()
      return 1
    end,
  }) do
    local refreshes = 0
    local component = create({
      name = "invalid change check",
      will_change = check,
      refresh = function()
        refreshes = refreshes + 1
        local text = tostring(refreshes)
        return { text = text, hltext = text }
      end,
    })
    component:request(context())
    wait_status(component, "ready")
    component:request(context(), true)
    wait_status(component, "ready")
    t.assert_eq(2, refreshes)
    component:request(context())
    t.assert_eq("failed", component.status)
    t.assert_eq("2", component:format(context(), 20))
    component:request(context())
    wait_status(component, "ready")
    t.assert_eq(3, refreshes)
  end
end)

t:test("runtimes sharing a raw definition keep independent comparison snapshots", function()
  local refreshes = 0
  local source = {
    name = "shared definition",
    will_change = function(ctx, _, snapshot)
      return ctx.value ~= snapshot.text
    end,
    refresh = function(ctx)
      refreshes = refreshes + 1
      return { text = ctx.value, hltext = ctx.value }
    end,
  }
  local first, second = create(source), create(source)
  first:request(context("A"))
  second:request(context("B"))
  wait_status(first, "ready")
  wait_status(second, "ready")
  first:request(context("A"))
  second:request(context("B"))
  t.assert_eq("ready", first.status)
  t.assert_eq("ready", second.status)
  t.assert_eq(2, refreshes)
  first:request(context("B"))
  wait_status(first, "ready")
  second:request(context("B"))
  t.assert_eq("ready", second.status)
  t.assert_eq(3, refreshes)
end)

t:test("cancellation from completion cleanup prevents committing its candidate", function()
  local component ---@type era.m.nvimbar.Component
  local resolve ---@type fun(data: any): nil
  component = create({
    name = "cancel during cleanup",
    refresh = function(_, token)
      token:on_cancel(function()
        component:cancel()
      end)
      local future
      future, resolve = Future.new_with_resolver()
      return future
    end,
  })
  component:request(context())
  wait_status(component, "running")
  resolve({ text = "cancelled", hltext = "cancelled" })
  t.assert_eq("idle", component.status)
  t.assert_nil(component.snapshot)
end)

t:test("a cancellation callback can request new work without losing its context or force flag", function()
  local component ---@type era.m.nvimbar.Component
  local acquired, tokens = {}, {}
  component = create({
    name = "request during cancellation",
    will_change = function()
      return false
    end,
    refresh = function(ctx, token)
      acquired[#acquired + 1] = ctx.value
      tokens[#tokens + 1] = token
      if ctx.value == "old" then
        token:on_cancel(function()
          component:request(context("new"), true)
        end)
        return Future.new(function() end)
      end
      return { text = ctx.value, hltext = ctx.value }
    end,
  })
  component:request(context("old"))
  wait_status(component, "running")
  component:cancel()
  t.assert_eq("queued", component.status)
  wait_status(component, "ready")
  t.assert_true(vim.deep_equal({ "old", "new" }, acquired))
  t.assert_true(tokens[1]:is_cancelled())
  t.assert_eq("new", component:format(context("new"), 20))
end)

t:test("cancelling queued work permits a fresh request before the old slot drains", function()
  local acquired = {}
  local component = create({
    name = "replace cancelled queue entry",
    refresh = function(ctx)
      acquired[#acquired + 1] = ctx.value
      return { text = ctx.value, hltext = ctx.value }
    end,
  })
  component:request(context("old"))
  component:cancel()
  component:request(context("new"))
  wait_status(component, "ready")
  t.assert_true(vim.deep_equal({ "new" }, acquired))
  component:request(context("again"))
  wait_status(component, "ready")
  t.assert_true(vim.deep_equal({ "new", "again" }, acquired))
end)

t:test("failed refreshes preserve the last snapshot and recover on a new request", function()
  local component = create({
    name = "failure",

    refresh = function(ctx)
      if ctx.value == "bad" then
        return Future.reject("temporary error")
      end
      return { text = ctx.value, hltext = ctx.value }
    end,
  })
  component:request(context("good"))
  wait_status(component, "ready")
  component:request(context("bad"))
  wait_status(component, "failed")
  t.assert_eq("good", component:format(context("bad"), 20))
  component:request(context("recovered"))
  wait_status(component, "ready")
  t.assert_eq("recovered", component:format(context("recovered"), 20))
end)

t:test("timeouts release running work and cancellation prevents a late write", function()
  local token, resolve
  local component = create({
    name = "timeout",

    timeout = 15,
    refresh = function(_, current_token)
      token = current_token
      local future
      future, resolve = Future.new_with_resolver({ token = token })
      return future
    end,
  })
  component:request(context())
  wait_status(component, "failed")
  t.assert_true(token:is_cancelled())
  resolve({ text = "late", hltext = "late" })
  t.assert_eq(nil, component.snapshot)
end)

t:test("disposing queued or running components prevents publication", function()
  local published, refreshed = 0, 0
  local queued = create({
    name = "queued disposal",

    refresh = function()
      refreshed = refreshed + 1
    end,
  })
  queued:request(context())
  queued:dispose()
  local resolve
  local running = create({
    name = "running disposal",

    refresh = function(_, token)
      local future
      future, resolve = Future.new_with_resolver({ token = token })
      return future
    end,
  }, function()
    published = published + 1
  end)
  running:request(context())
  wait_status(running, "running")
  running:dispose()
  resolve({ text = "late", hltext = "late" })
  t.assert_eq(0, refreshed)
  t.assert_eq(0, published)
  t.assert_eq(nil, running.snapshot)
end)

t:test("layout uses the latest width without requesting fresh data", function()
  local refreshed = 0
  local component = create({
    name = "width",

    refresh = function()
      refreshed = refreshed + 1
      return "abcdefgh"
    end,
    render = function(data, _, width)
      local value = data:sub(1, width)
      return value, value
    end,
  })
  component:request(context())
  wait_status(component, "ready")
  t.assert_eq("abc", component:format(context(), 3))
  t.assert_eq("abcdef", component:format(context(), 6))
  t.assert_eq(1, refreshed)
end)

t:test("will_change can distinguish false and nil dependencies with an empty snapshot", function()
  local refreshed = 0
  local component = create(function()
    return {
      name = "empty snapshot",
      will_change = function(ctx, prev_context, snapshot)
        t.assert_nil(snapshot)
        return ctx.value ~= prev_context.value
      end,
      refresh = function()
        refreshed = refreshed + 1
        return nil
      end,
    }
  end)
  component:request(context(false))
  wait_status(component, "ready")
  component:request(context(false))
  t.assert_eq(1, refreshed)
  t.assert_eq("ready", component.status)
  component:request(context(nil))
  wait_status(component, "ready")
  component:request(context(nil))
  t.assert_eq(2, refreshed)
  t.assert_eq("ready", component.status)
end)

t:test("owner changes reject in-flight data even without another request", function()
  local current, published = true, 0
  local future, resolve = Future.new_with_resolver()
  local component = create({
    name = "owner",
    refresh = function()
      return future
    end,
  }, function()
    published = published + 1
  end, function()
    return current
  end)
  component:request(context())
  wait_status(component, "running")
  current = false
  resolve({ text = "old", hltext = "old" })
  t.assert_eq("idle", component.status)
  t.assert_nil(component.snapshot)
  t.assert_eq(0, published)
end)

t:test("owner validation failures settle the component and permit a retry", function()
  local fail = false
  local future, resolve = Future.new_with_resolver()
  local component = create(
    {
      name = "validation",
      refresh = function()
        return future
      end,
    },
    nil,
    function()
      if fail then
        error("owner unavailable")
      end
      return true
    end
  )
  component:request(context())
  wait_status(component, "running")
  fail = true
  resolve({ text = "value", hltext = "value" })
  t.assert_eq("failed", component.status)
  t.assert_nil(component.snapshot)
  fail = false
  component:request(context())
  wait_status(component, "ready")
  t.assert_eq("value", component:format(context(), 20))
end)

t:test("initialization failures retry on the next request", function()
  local attempts = 0
  local component = create(function()
    attempts = attempts + 1
    if attempts == 1 then
      error("factory unavailable")
    end
    return {
      name = "retry",
      refresh = function()
        return { text = "ready", hltext = "ready" }
      end,
    }
  end)
  component:request(context())
  wait_status(component, "failed")
  t.assert_nil(component.definition)
  component:request(context())
  wait_status(component, "ready")
  t.assert_eq(2, attempts)
end)

t:test("a failed refresh retries even when will_change returns false", function()
  local attempts = 0
  local component = create({
    name = "retry",
    will_change = function()
      return false
    end,
    refresh = function()
      attempts = attempts + 1
      if attempts == 1 then
        return Future.reject("temporary failure")
      end
      return { text = "ready", hltext = "ready" }
    end,
  })
  component:request(context())
  wait_status(component, "failed")
  component:request(context())
  wait_status(component, "ready")
  t.assert_eq(2, attempts)
end)

t:test("a pending will_change failure discards the candidate and permits a retry", function()
  local fail, token = false, nil
  local future, resolve = Future.new_with_resolver()
  local component = create({
    name = "change check failure",
    will_change = function(ctx, prev_context)
      if fail then
        error("change check unavailable")
      end
      return ctx.value ~= prev_context.value
    end,
    refresh = function(_, current_token)
      token = current_token
      return future
    end,
  })
  component:request(context("one"))
  wait_status(component, "running")
  fail = true
  component:request(context("two"))
  t.assert_eq("running", component.status)
  resolve({ text = "old", hltext = "old" })
  t.assert_eq("failed", component.status)
  t.assert_true(token:is_cancelled())
  t.assert_nil(component.snapshot)
  component:request(context("two"))
  wait_status(component, "ready")
end)

t:test("an obsolete failure cannot overwrite the latest pending request", function()
  local reject_old
  local future = Future.new(function(_, reject)
    reject_old = reject
  end)
  local component = create({
    name = "obsolete failure",
    refresh = function(ctx)
      if ctx.value == "old" then
        return future
      end
      return { text = ctx.value, hltext = ctx.value }
    end,
  })
  component:request(context("old"))
  wait_status(component, "running")
  component:request(context("new"))
  local error_count = #errors
  reject_old("obsolete failure")
  wait_status(component, "ready")
  t.assert_eq(error_count, #errors)
  t.assert_eq("new", component:format(context(), 20))
end)

t:test("layout failures stay local and never request another publication", function()
  local changes, renders = 0, 0
  local component = create({
    name = "layout failure",
    refresh = function()
      return true
    end,
    render = function()
      renders = renders + 1
      error("invalid layout")
    end,
  }, function()
    changes = changes + 1
  end)
  component:request(context())
  wait_status(component, "ready")
  local error_count = #errors
  for _ = 1, 3 do
    t.assert_eq("", component:format(context(), 20))
  end
  t.assert_eq(3, renders)
  t.assert_eq(1, changes)
  t.assert_eq(error_count + 1, #errors)
  t.assert_eq("ready", component.status)
end)

t:test("layout observes pane geometry changes without reacquiring data", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 1, col = 1, width = 20, height = 2 })
  t:defer(function()
    vim.api.nvim_win_close(winnr, true)
  end)
  local refreshes = 0
  local component = create({
    name = "pane width",
    refresh = function()
      refreshes = refreshes + 1
      return { winnr = winnr }
    end,
    render = function(snapshot)
      local text = tostring(vim.api.nvim_win_get_width(snapshot.winnr))
      return text, text
    end,
  })
  component:request(context())
  wait_status(component, "ready")
  t.assert_eq("20", component:format(context(), 80))
  vim.api.nvim_win_set_width(winnr, 30)
  t.assert_eq("30", component:format(context(), 80))
  t.assert_eq(1, refreshes)
end)

t:test("Future results from libuv callbacks commit on the main loop", function()
  local timer = assert(vim.uv.new_timer())
  t:defer(function()
    timer:stop()
    timer:close()
  end)
  local component = create(
    {
      name = "libuv result",
      refresh = function()
        return Future.new(function(resolve)
          timer:start(1, 0, function()
            resolve({ text = "ready", hltext = "ready" })
          end)
        end)
      end,
    },
    nil,
    function()
      t.assert_false(vim.in_fast_event(), "owner validation requires the main loop")
      return true
    end
  )
  component:request(context())
  t.wait_until(function()
    return component.status == "ready" or component.status == "failed"
  end, 1000)
  t.assert_eq("ready", component.status, component.error)
  t.assert_eq("ready", component:format(context(), 20))
end)

t:run()
