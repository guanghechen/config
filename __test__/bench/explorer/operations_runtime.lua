---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.operations_runtime" ---@type string

local repo, directory, implementation, kind, entries, options = ...
options = options or {}
local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local baseline =
  assert(loadfile(here .. "/runtime.lua"))(repo, directory, implementation, entries, 0, "tree", { git = kind == "git" })
local native = implementation == "native"
local Git = require("era.m.git.state")

---@param future                        stl.c.Future
---@return any
local function await(future)
  assert(
    vim.wait(30000, function()
      return future:is_done()
    end, 1),
    "Future timed out"
  )
  assert(not future:is_failed(), future:get_error())
  local value = future:get_result()
  assert(type(value) ~= "table" or value.kind ~= "Rejected", vim.inspect(value))
  return value
end

bench.start("open", entries)
assert(
  vim.wait(30000, function()
    return bench.phase and bench.phase.done
  end, 1),
  "Widget did not open"
)
bench.timer:stop()
bench.timer:close()
local expected_rows = entries
if options.expanded then
  assert(kind == "copy" and options.files > 1)
  if native then
    bench.widget._action:activate()
  else
    bench.widget._action:open()
  end
  expected_rows = expected_rows + options.files
  assert(
    vim.wait(30000, function()
      local ready, rows = bench.ready()
      return ready and rows == expected_rows
    end, 2),
    "copy source did not expand"
  )
end

local marker = directory .. "/file-00000.lua"
local marker_row
if kind == "git" then
  await(Git.refresh(true))
  for row, line in ipairs(vim.api.nvim_buf_get_lines(bench.current_buffer(), 0, -1, false)) do
    if line:find("file-00000.lua", 1, true) then
      marker_row = row
      break
    end
  end
  assert(marker_row)
  assert(
    vim.wait(10000, function()
      return Git.is_ignored(directory .. "/a-ignored.lua")
    end, 1),
    "ignore collection did not complete"
  )
  local untracked = Git.snapshot():lookup(directory .. "/b-untracked.lua", false)
  assert(
    untracked and bit.band(untracked.codes, yoz.git.codes["?"]) ~= 0,
    "real Git did not collect the untracked fixture"
  )
end

---@param modified                      boolean
---@return boolean
local function git_published(modified)
  local info = Git.snapshot():lookup(marker, false)
  if not info or (bit.band(info.codes, yoz.git.codes.M) ~= 0) ~= modified then
    return false
  end
  if native then
    local view = bench.current_view()
    local cache = view._filetree_annotations
    local item = cache and cache.frame == view:frame():id() and cache.rows[marker_row - cache.first + 1]
    return item and (bit.band(item.git, yoz.git.codes.M) ~= 0) == modified or false
  end
  local item = bench.widget:get_render_result().git_by_lnum[marker_row]
  return item and (item.text:find("M", 1, true) ~= nil) == modified or false
end

if kind == "git" then
  assert(
    vim.wait(10000, function()
      return git_published(false)
    end, 1),
    "initial Git status was not published"
  )
end

---@return nil
local function io_complete()
  local operation = bench.operation
  if operation.io_at then
    return
  end
  operation.io_at = vim.uv.hrtime()
  local usage = bench.usage()
  operation.job_cpu_ms = (usage.cpu_us - operation.usage.cpu_us) / 1000
  operation.job_main_cpu_ms = usage.main_us and (usage.main_us - operation.usage.main_us) / 1000
end

if kind == "copy" then
  if native then
    local data = bench.widget._session.data
    local track = data._track_job
    data._track_job = function(self, job, observe)
      bench.copy_job = job
      return track(self, job, function(status)
        assert(not status.error and not status.cancelled, vim.inspect(status))
        if status.terminal then
          io_complete()
        end
        return observe(status)
      end)
    end
  else
    local resource = bench.widget._action._ctx.resource_manager
    local copy = resource.copy
    resource.copy = function(self, ...)
      local status = copy(self, ...)
      assert(status == "success", "legacy copy failed: " .. tostring(status))
      io_complete()
      return status
    end
  end
end

---@return nil
local function poll()
  local operation = bench.operation
  if not operation or not operation.started or operation.done then
    return
  end
  -- Completion is driven by the real Job/query notification; only publication may still need checking.
  if not (kind == "git" and operation.query_at or kind == "copy" and operation.io_at) then
    return
  end
  operation.readiness_checks = operation.readiness_checks + 1
  local now = vim.uv.hrtime()
  local ready, rows = bench.ready()
  operation.observed_rows = rows
  if kind == "git" then
    ready = ready and operation.query_at and git_published(operation.modified)
  else
    ready = ready and operation.io_at and rows == expected_rows + (options.outside and 0 or 1)
    if native then
      ready = ready and not bench.widget._session:busy()
    end
  end
  if ready then
    operation.max_tick_gap_ms = math.max(operation.max_tick_gap_ms, (now - operation.last_tick) / 1000000)
    operation.done = now
    local usage = bench.usage()
    operation.cpu_ms = (usage.cpu_us - operation.usage.cpu_us) / 1000
    operation.main_cpu_ms = usage.main_us and (usage.main_us - operation.usage.main_us) / 1000
    if bench.on_operation then
      bench.on_operation(bench.operation_status())
    end
  end
end

bench.timer = assert(vim.uv.new_timer())
bench.timer:start(
  2,
  2,
  vim.schedule_wrap(function()
    local operation = bench.operation
    if operation and operation.started and not operation.done then
      local now = vim.uv.hrtime()
      operation.max_tick_gap_ms = math.max(operation.max_tick_gap_ms, (now - operation.last_tick) / 1000000)
      operation.last_tick = now
      poll()
    end
  end)
)

---@param value                         string|boolean
---@return nil
function bench.run_operation(value)
  bench.operation = { max_tick_gap_ms = 0, readiness_checks = 0 }
  local operation = bench.operation
  vim.schedule(function()
    if kind == "git" then
      local fd = assert(vim.uv.fs_open(marker, "w", 384))
      assert(vim.uv.fs_write(fd, value and "changed\n" or "base\n", 0))
      assert(vim.uv.fs_close(fd))
      operation.modified = value
    else
      vim.ui.input = function(_, complete)
        vim.schedule(function()
          complete(value)
        end)
      end
    end
    operation.usage = bench.usage()
    operation.started = vim.uv.hrtime()
    operation.last_tick = operation.started
    if kind == "git" then
      Git.refresh(true):finally(function(ok, error)
        assert(ok, tostring(error))
        operation.query_at = vim.uv.hrtime()
        poll()
      end)
    else
      vim.api.nvim_input("c")
    end
  end)
end

---@return table
function bench.operation_status()
  local operation = bench.operation or {}
  return {
    started = operation.started or false,
    done = operation.done or false,
    io_at = operation.io_at,
    query_at = operation.query_at,
    cpu_ms = operation.cpu_ms,
    main_cpu_ms = operation.main_cpu_ms,
    job_cpu_ms = operation.job_cpu_ms,
    job_main_cpu_ms = operation.job_main_cpu_ms,
    readiness_checks = operation.readiness_checks,
    max_tick_gap_ms = operation.max_tick_gap_ms,
    observed_rows = operation.observed_rows,
    job_started = bench.copy_job ~= nil,
    session_busy = native and bench.widget._session:busy() or false,
    errors = bench.errors,
  }
end

return { baseline = baseline, open_memory = bench.memory() }
