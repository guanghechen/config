---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.filetree.runtime" ---@type string

local fixture = require("__test__.support.filetree").new("ux.filetree.runtime")
local t, filetree = fixture.t, fixture.filetree
local await, write, directory = fixture.await, fixture.write, fixture.directory

t:test("hidden idle data stops polling and a new request or view resumes it", function()
  local path = directory()
  write(path .. "/first")
  local data = await(filetree.open(path))
  local state = await(data:create_state())
  local owner, calls, sleeping = data._tree, 0, false
  local poll = owner._poll
  t:patch_table(owner, "_poll", function(self)
    calls = calls + 1
    local value = poll(self)
    sleeping = value == nil
    return value
  end)
  local view = filetree.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() and view:frame():header().row_count == 1
  end, 10000)
  view:detach()
  t.wait_until(function()
    return sleeping and data:watch_status().directories == 0
  end, 10000)
  vim.wait(50, function()
    return false
  end, 50)
  local idle_calls = calls
  vim.wait(50, function()
    return false
  end, 50)
  t.assert_eq(idle_calls, calls, "no polling while this retained data is idle")
  write(path .. "/second")
  local resource = await(data:resolve(path .. "/second"))
  t.assert_eq(path .. "/second", resource:path())
  t.wait_until(function()
    return calls > idle_calls and sleeping
  end, 10000)
  view = filetree.attach(state, { keymaps = false })
  t.wait_until(function()
    return view:frame() and view:frame():header().row_count == 2 and data:watch_status().directories > 0
  end, 10000)
  write(path .. "/third")
  t.wait_until(function()
    return view:frame():header().row_count == 3
  end, 10000)
end)

t:test("hidden task deadlines deliver failure without another request and then stop polling", function()
  for _, deadline in ipairs({ 0, 100 }) do
    local failures = {}
    local data = await(filetree.open(directory(), {
      on_effect = function(effect)
        if effect.kind == "TaskFailed" then
          failures[#failures + 1] = effect
        end
      end,
    }))
    local state = await(data:create_state())
    local owner, calls, sleeping = data._tree, 0, false
    local poll = owner._poll
    t:patch_table(owner, "_poll", function(self)
      calls = calls + 1
      local value = poll(self)
      sleeping = value == nil
      return value
    end)
    local task = await(state:lock_selection(deadline))
    t.wait_until(function()
      return #failures == 1 and sleeping
    end, 5000, "deadline failure must arrive without another native request")
    t.assert_eq(task.token, failures[1].lock)
    t.assert_false(state:status().locked)
    local idle_calls = calls
    vim.wait(50, function()
      return false
    end, 50)
    t.assert_eq(1, #failures)
    t.assert_eq(idle_calls, calls)
  end
end)

t:test("a deadline callback can retry with an already completed native ticket", function()
  local state, retry
  local failures = {}
  local data = await(filetree.open(directory(), {
    on_effect = function(effect)
      if effect.kind == "TaskFailed" then
        failures[#failures + 1] = effect.lock
        if #failures == 1 then
          retry = state:lock_selection(100)
        end
      end
    end,
  }))
  state = await(data:create_state())
  local native = state._native
  t:patch_table(state, "_native", {
    status = function()
      return native:status()
    end,
    lock_selection = function(_, revision, deadline)
      local ticket = native:lock_selection(revision, deadline)
      -- Fix the supported boundary where native completion precedes async.run.
      local started = vim.uv.hrtime()
      while not ticket:poll() do
        t.assert_true(vim.uv.hrtime() - started < 1000000000, "native lock did not complete")
        vim.uv.sleep(1)
      end
      return ticket
    end,
  })
  local first = await(state:lock_selection(100))
  t.wait_until(function()
    return #failures == 2
  end, 5000, "retry expiry must not need another native request")
  t.assert_true(retry:is_done())
  t.assert_eq(first.token, failures[1])
  t.assert_eq(retry:get_result().token, failures[2])
  t.assert_false(state:status().locked)
end)

t:test("prepared and unlocked hidden tasks release deadline polling demand", function()
  local failures = 0
  local data = await(filetree.open(directory(), {
    on_effect = function(effect)
      if effect.kind == "TaskFailed" then
        failures = failures + 1
      end
    end,
  }))
  local state = await(data:create_state())
  local owner, calls, sleeping = data._tree, 0, false
  local poll = owner._poll
  t:patch_table(owner, "_poll", function(self)
    calls = calls + 1
    local value = poll(self)
    sleeping = value == nil
    return value
  end)
  local task = await(state:lock_selection(1000))
  t.assert_eq("Ready", await(task:prepare_sources()).kind)
  t.wait_until(function()
    return sleeping
  end, 5000)
  local idle_calls = calls
  vim.wait(1100, function()
    return false
  end, 50)
  t.assert_true(state:status().locked, "prepared tasks survive their preparation deadline")
  t.assert_eq(idle_calls, calls)
  await(task:unlock())
  task = await(state:lock_selection(1000))
  await(task:unlock())
  t.wait_until(function()
    return sleeping
  end, 5000)
  idle_calls = calls
  vim.wait(50, function()
    return false
  end, 50)
  t.assert_false(state:status().locked)
  t.assert_eq(idle_calls, calls)
  t.assert_eq(0, failures)
end)

t:test("native List loads a real directory and preserves old resource paths on refresh", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/before", 448))
  write(path .. "/before/file")
  local data = await(filetree.open(path))
  local state = await(data:create_state(nil, { mode = "list" }))
  local view = filetree.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return vim.deep_equal(vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, true), { "  before", "  before/file" })
  end, 10000)
  local old = view:frame()
  local file = old:node_at(2)
  local resource = data:inspect(old:source(), file)
  t.assert_eq(path .. "/before/file", resource:path())
  assert(vim.uv.fs_rename(path .. "/before", path .. "/after"))
  await(data:refresh(state))
  t.wait_until(function()
    return vim.deep_equal(vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, true), { "  after", "  after/file" })
  end, 10000)
  t.assert_eq(file, view:frame():node_at(2))
  t.assert_eq(path .. "/after/file", data:inspect(view:frame():source(), file):path())
  t.assert_eq(path .. "/before/file", resource:path())
  t.assert_eq("before/file", old:rows(2, 2).labels[1])
end)

t:test("paged native reads keep progressing while only the state and view remain", function()
  local path = directory()
  for i = 1, 1100 do
    write(path .. ("/file-%04d"):format(i))
  end
  local data = await(filetree.open(path))
  local state = await(data:create_state(nil, { mode = "list" }))
  local view = filetree.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  data = nil
  collectgarbage("collect")
  t.wait_until(function()
    return view:frame() and view:frame():header().row_count == 1100 and vim.api.nvim_buf_line_count(view.bufnr) == 1100
  end, 10000)
  t.assert_eq("  file-1100", vim.api.nvim_buf_get_lines(view.bufnr, -2, -1, true)[1])
end)

t:test("native watch updates the actual buffer without manual refresh", function()
  local path = directory()
  local data = await(filetree.open(path))
  local state = await(data:create_state(nil, { mode = "list" }))
  local view = filetree.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    local status = data:watch_status()
    t.assert_eq(nil, status.error)
    return status.directories == 1 and not data._native:is_busy()
  end, 10000)
  write(path .. "/observed")
  t.wait_until(function()
    return vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, true)[1] == "  observed"
  end, 10000)
  local id = view:frame():node_at(1)
  assert(vim.uv.fs_rename(path .. "/observed", path .. "/renamed"))
  t.wait_until(function()
    return vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, true)[1] == "  renamed"
  end, 10000)
  t.assert_eq(id, view:frame():node_at(1))
end)

t:run()
