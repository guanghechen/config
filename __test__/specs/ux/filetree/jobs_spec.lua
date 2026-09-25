---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.filetree.jobs" ---@type string

local fixture = require("__test__.support.filetree").new("ux.filetree.jobs")
local t, filetree = fixture.t, fixture.filetree
local await, write, directory = fixture.await, fixture.write, fixture.directory

t:test("native Job confirms one conflict and consumes opaque prepared NodeIds", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/dst", 448))
  write(path .. "/source")
  write(path .. "/dst/source")
  local data = await(filetree.open(path))
  local source = await(data:resolve(path .. "/source"))
  local target = await(data:resolve(path .. "/dst"))
  local state = await(data:create_state())
  await(state:select_node({ source:node() }, true))
  local task = await(state:lock_selection())
  local ready = await(task:prepare_sources())
  t.assert_eq("Ready", ready.kind)
  local job = data:start_operation({
    kind = "copy",
    source = ready.source,
    nodes = ready.subtree_roots,
    target = target,
    task = { state = state, lock = task.token, cleanup = ready.cleanup },
  })
  t:defer(function()
    job:cancel()
  end)
  t.wait_until(function()
    return job:status().confirmation ~= nil
  end, 10000)
  local confirmation = job:status().confirmation
  t.assert_eq(path .. "/dst/source", confirmation.target)
  job:confirm(confirmation.token, true)
  t.wait_until(function()
    return job:status().terminal
  end, 10000)
  local status = job:status()
  t.assert_eq(nil, status.error)
  t.assert_eq("success", status.cleanup)
  t.assert_false(state:status().locked)
  local result = job:results(1, status.results)
  t.assert_eq("success", result[1].status)
  t.assert_eq(nil, result[1].sync_error)
  t.assert_eq(source:node(), result[1].node)
end)

t:test("Job finishes multiple pages after the Lua data facade is collected", function()
  local path = directory()
  assert(vim.uv.fs_mkdir(path .. "/src", 448))
  assert(vim.uv.fs_mkdir(path .. "/dst", 448))
  for i = 1, 600 do
    write(path .. "/src/file-" .. i)
  end
  local data = await(filetree.open(path))
  local source = await(data:resolve(path .. "/src"))
  local target = await(data:resolve(path .. "/dst"))
  local job =
    data:start_operation({ kind = "copy", source = source:source(), nodes = { source:node() }, target = target })
  t:defer(function()
    job:cancel()
  end)
  data, source, target = nil, nil, nil
  collectgarbage("collect")
  t.wait_until(function()
    return job:status().terminal
  end, 15000)
  t.assert_eq(nil, job:status().error)
  local results = job:results(1, job:status().results)
  t.assert_eq("success", results[1].status)
  t.assert_eq(nil, results[1].sync_error)
  t.assert_true(vim.uv.fs_stat(path .. "/dst/src/file-600") ~= nil)
end)

t:run()
