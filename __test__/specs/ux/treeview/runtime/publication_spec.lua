local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new()
bootstrap.with_native(t)
local treeview = require("ux.treeview")
local support = require("__test__.support.treeview")
local fixture = support.fixture

t:test("source frames coalesce while accepted selection publishes the latest source immediately", function()
  local data, state, a = fixture()
  local view = treeview.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() and not view._busy
  end, 5000)
  t.await(view:set_cursor(1))
  t.wait_until(function()
    return view._header.cursor == a and not view._busy
  end, 5000)
  -- Hold this publication boundary deterministically instead of asserting wall-clock timing.
  view._source_after = vim.uv.hrtime() + 1000000000
  local original = view:frame():id()
  support.applied(data:batch({ { kind = "update", id = a, label = "first" } }))
  t.wait_until(function()
    return view._source_timer ~= nil
  end, 5000)
  local timer = view._source_timer
  support.applied(data:batch({ { kind = "update", id = a, label = "latest" } }))
  view:_poll()
  t.assert_eq(original, view:frame():id())
  support.applied(view:select("select_node", true))
  t.wait_until(function()
    return view:frame():node(a).label == "latest" and view:frame():header().summary.known_roots == 1
  end, 5000)
  t.assert_nil(view._source_timer)
  t.assert_true(timer:is_closing())

  view._source_after = vim.uv.hrtime() + 1000000000
  support.applied(data:batch({ { kind = "update", id = a, label = "closed" } }))
  t.wait_until(function()
    return view._source_timer ~= nil
  end, 5000)
  timer = view._source_timer
  view:detach()
  t.assert_nil(view._source_timer)
  t.assert_true(timer:is_closing())
end)

t:test("the first nonempty source frame bypasses a pending display deadline", function()
  local data = treeview.new_data()
  support.applied(data:import({ { key = "root", label = "root", can_expand = true } }))
  local root = data:source():id("root")
  local state = t.await(data:create_state({ kind = "children_of", node = root }))
  local view = treeview.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() and view:frame():header().row_count == 0 and not view._busy
  end, 5000)
  view._source_after = vim.uv.hrtime() + 30000000000
  support.applied(data:batch({ { kind = "insert", key = "first", label = "first", parent = "root" } }))
  t.wait_until(function()
    return view:frame():header().row_count == 1 and not view._busy
  end, 5000, "the first visible content waited for source pacing")
  t.assert_nil(view._source_timer)
end)

t:test("active frame preparation still applies backpressure to subsequent provider pages", function()
  local Future = require("stl.c.future")
  local pages, commit = 0, nil
  local pending = Future.new(function(resolve)
    commit = resolve
  end)
  local preparing = false
  local data = treeview.new_data({
    read_children = function()
      pages = pages + 1
      return { records = { { key = "page-" .. pages, label = "page-" .. pages } }, done = pages == 2 }
    end,
  })
  support.applied(data:batch({ { kind = "insert", key = "root", label = "root", can_expand = true } }))
  local state = t.await(data:create_state({ kind = "children_of", node = data:source():id("root") }))
  local view
  view = treeview.attach(state, {
    keymaps = false,
    prepare_frame = function()
      if not preparing then
        preparing = true
        return pending
      end
      return Future.resolve(function() end)
    end,
    on_frame = function()
      if view then
        view._source_after = 0
      end
    end,
  })
  view._source_after = 0
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return preparing
  end, 5000)
  t.assert_eq("Inspected", t.await(state:inspect_selection()).kind)
  t.assert_eq(1, pages, "the provider must wait while the first nonempty frame is being prepared")
  commit(function() end)
  t.wait_until(function()
    return pages == 2 and view:frame() and view:frame():header().row_count == 2 and not view._busy
  end, 5000)
end)

t:test("reentrant watch survives an idle result and explicit unwatch stays removed", function()
  local async = require("ux.treeview.async")
  local calls = 0
  local owner = {
    _poll = function(self)
      calls = calls + 1
      if calls == 1 then
        async.watch(self)
      else
        async.unwatch(self)
      end
    end,
  }
  t:defer(function()
    async.unwatch(owner)
  end)
  async.watch(owner)
  t.wait_until(function()
    return calls >= 2
  end, 1000)
  async.run({
    poll = function()
      return true, nil
    end,
  })
  vim.wait(50, function()
    return false
  end, 50)
  t.assert_eq(2, calls, "an unrelated request must not revive an explicitly removed watcher")
end)

t:test("a visible idle view sleeps and native publication wakes it without another Lua request", function()
  local data, state, a = fixture()
  local calls, poll = 0, data._poll
  t:patch_table(data, "_poll", function(self)
    calls = calls + 1
    return poll(self)
  end)
  local view = treeview.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() and not view._busy
  end, 5000)
  vim.wait(100, function()
    return false
  end, 10)
  local idle_calls = calls
  vim.wait(150, function()
    return false
  end, 10)
  t.assert_eq(idle_calls, calls, "an unchanged visible view must not poll on a timer")
  local ticket = data._native:batch({
    base_revision = data:source():revision(),
    operations = { { kind = "update", id = a, label = "awakened" } },
  })
  t.wait_until(function()
    return view:frame():node(a).label == "awakened"
  end, 5000, "native publication must wake the sleeping Lua view")
  local done, result = ticket:poll()
  t.assert_true(done)
  t.assert_eq("Applied", result.kind, vim.inspect(result))
  t.assert_true(calls > idle_calls)
end)

t:test("closing a notification lease releases capacity before Lua garbage collection", function()
  local data = treeview.new_data()
  local descriptors = assert(vim.uv.pipe({ nonblock = true }, { nonblock = false }))
  t:defer(function()
    vim.uv.fs_close(descriptors.write)
    vim.uv.fs_close(descriptors.read)
  end)
  local closed = {}
  for index = 1, 128 do
    local subscription = data._native:subscribe(descriptors.write)
    subscription:close()
    closed[index] = subscription
  end
  t.assert_eq(128, #closed)
end)

t:test("notification readers do not retain a collected Lua owner while native data remains alive", function()
  local data = treeview.new_data()
  support.applied(data:import({ { key = "root", label = "root" } }))
  local retained = data._native
  local weak = setmetatable({ data, data._notification.subscription, data._notification.reader }, { __mode = "v" })
  data = nil
  t.wait_until(function()
    collectgarbage("collect")
    return weak[1] == nil and weak[2] == nil and weak[3] == nil
  end, 5000, "owner collection must close its pipe without waiting for another publication")
  local source = retained:source()
  t.assert_eq("root", source:node(source:id("root")).label)
end)

t:test("a failed notification stream reports once and preserves publication through polling", function()
  local data, state, a = fixture()
  local errors = {}
  t:patch_table(stl.reporter, "error", function(value)
    errors[#errors + 1] = value.message
  end)
  local view = treeview.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() and not view._busy
  end, 5000)
  data._notification.subscription:close()
  t.wait_until(function()
    return data._notification_failed
  end, 5000)
  t.assert_eq(1, #errors)
  t.assert_true(errors[1]:find("notification stream closed", 1, true) ~= nil)
  local ticket = data._native:batch({
    base_revision = data:source():revision(),
    operations = { { kind = "update", id = a, label = "recovered" } },
  })
  t.wait_until(function()
    return view:frame():node(a).label == "recovered"
  end, 5000)
  t.assert_true(ticket:poll())
  t.assert_eq(1, #errors)
end)

t:test("native view polling reuses unchanged frames and returns a complete changed frame", function()
  local data, state, a = fixture()
  local view = treeview.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  local first = view:frame()
  local unchanged, error = view._native:poll_frame(first)
  t.assert_nil(unchanged)
  t.assert_nil(error)
  support.applied(data:batch({ { kind = "update", id = a, label = "updated" } }))
  t.wait_until(function()
    return view:frame():rows(1, 1).labels[1] == "updated"
  end, 5000)
  local changed
  changed, error = view._native:poll_frame(first)
  t.assert_eq(view:frame():id(), changed:id())
  t.assert_eq("updated", changed:rows(1, 1).labels[1])
  t.assert_nil(error)
  unchanged, error = view._native:poll_frame(changed)
  t.assert_nil(unchanged)
  t.assert_nil(error)
end)

t:test("frame preparation preserves the old publication through retries and stale results", function()
  local data, state, a = fixture()
  local delayed, pending, commits, errors = false, {}, {}, {}
  local committed_frame
  ---@param label                       string
  ---@return fun(frame: yoz.ux.treeview.Frame): nil
  local function commit(label)
    return function(frame)
      committed_frame = frame:id()
      commits[#commits + 1] = label
    end
  end
  local view = treeview.attach(state, {
    keymaps = false,
    prepare_frame = function()
      if not delayed then
        return stl.c.Future.resolve(commit("initial"))
      end
      return stl.c.Future.new(function(resolve, reject)
        pending[#pending + 1] = { resolve = resolve, reject = reject }
      end)
    end,
    on_frame = function(frame)
      t.assert_eq(frame:id(), committed_frame, "decorations must be committed before observers run")
    end,
    on_error = function(error)
      errors[#errors + 1] = error
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  local original, tick = view:frame():id(), vim.api.nvim_buf_get_changedtick(view.bufnr)
  delayed = true
  support.applied(data:batch({ { kind = "update", id = a, label = "intermediate" } }))
  t.wait_until(function()
    return #pending == 1
  end, 5000)
  t.assert_eq(original, view:frame():id())
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr))
  pending[1].resolve(false)
  t.wait_until(function()
    return #pending == 2
  end, 5000)
  support.applied(data:batch({ { kind = "update", id = a, label = "latest" } }))
  pending[2].resolve(commit("stale"))
  t.wait_until(function()
    return #pending == 3
  end, 5000)
  t.assert_eq(1, #commits, "a superseded preparation must not run its commit")
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr))
  pending[3].resolve(commit("latest"))
  t.wait_until(function()
    return view:frame():node(a).label == "latest"
  end, 5000)
  t.assert_eq("latest", commits[2])
  t.assert_eq("    latest", vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1])

  local published = view:frame():id()
  support.applied(data:batch({ { kind = "update", id = a, label = "failed" } }))
  t.wait_until(function()
    return #pending == 4
  end, 5000)
  pending[4].reject("decoration preparation failed")
  t.wait_until(function()
    return #errors == 1
  end, 5000)
  t.assert_eq(published, view:frame():id())
  t.assert_eq("    latest", vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1])
  support.applied(data:batch({ { kind = "update", id = a, label = "recovered" } }))
  t.wait_until(function()
    return #pending == 5
  end, 5000)
  pending[5].resolve(commit("recovered"))
  t.wait_until(function()
    return view:frame():node(a).label == "recovered"
  end, 5000)
  t.assert_eq(1, #errors)
end)

t:test("frame preparation rechecks viewport size and ignores detached completions", function()
  local data = treeview.new_data()
  local records = { { key = "root", label = "root", can_expand = true } }
  for index = 1, 40 do
    records[#records + 1] = { key = "item-" .. index, parent = "root", label = "item-" .. index }
  end
  support.applied(data:import(records))
  local state = t.await(data:create_state({ kind = "children_of", node = data:source():id("root") }))
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = 0,
    col = 0,
    width = 40,
    height = 6,
    style = "minimal",
  })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  local pending, commits = {}, 0
  local view = treeview.attach(state, {
    winnr = winnr,
    keymaps = false,
    prepare_frame = function(_, _, first, last)
      return stl.c.Future.new(function(resolve)
        pending[#pending + 1] = { first = first, last = last, resolve = resolve }
      end)
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return #pending == 1
  end, 5000)
  vim.api.nvim_win_set_config(winnr, { height = 10 })
  pending[1].resolve(function()
    commits = commits + 1
  end)
  t.wait_until(function()
    return #pending == 2
  end, 5000)
  t.assert_eq(0, commits, "a preparation for the previous viewport must be discarded")
  t.assert_true(pending[2].last > pending[1].last)
  pending[2].resolve(function()
    commits = commits + 1
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  t.assert_eq(1, commits)
  support.applied(data:batch({ { kind = "update", id = data:source():id("item-1"), label = "changed" } }))
  t.wait_until(function()
    return #pending == 3
  end, 5000)
  view:detach()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { "replacement window content" })
  pending[3].resolve(function()
    commits = commits + 1
  end)
  t.assert_eq(1, commits, "a closed view must not apply late decorations")
  t.assert_eq(bufnr, vim.api.nvim_win_get_buf(winnr))
  t.assert_eq("replacement window content", vim.api.nvim_buf_get_lines(bufnr, 0, 1, true)[1])
end)

t:run()
