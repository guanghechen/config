---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.move" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local harness = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
local root = vim.env.NVIM_EXPLORER_BENCH_CHECKOUT or harness
local extension = vim.uv.os_uname().sysname == "Windows_NT" and "dll" or "so"
local native_path = vim.env.NVIM_EXPLORER_BENCH_NATIVE or root .. "/lua/yoz." .. extension
local count, buffer_count = tonumber(arg[1]) or 200, tonumber(arg[2]) or 0
local mode, profiling = arg[3] or "none", arg[4] == "profile"
assert(count >= 1 and count <= 2000 and count % 1 == 0)
assert(buffer_count >= 0 and buffer_count <= 2000 and buffer_count % 1 == 0)
assert(mode == "none" or mode == "notify" or mode == "async")
assert(arg[4] == nil or arg[4] == "profile")
assert(arg[5] == nil)
vim.api.nvim_set_current_dir(root)
vim.opt.runtimepath = { root, assert(vim.env.VIMRUNTIME), vim.api.nvim__get_lib_dir() }
vim.opt.packpath = vim.opt.runtimepath:get()
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local loadlib = package.loadlib
package.loadlib = function(path, symbol)
  return loadlib(symbol == "luaopen_yoz" and native_path or path, symbol)
end
local fixture = require("__test__.support.explorer").new("explorer.move.benchmark")
package.loadlib = loadlib
local t, await = fixture.t, fixture.await
local buffers = require("era.m.explorer.buffers")
local Metrics = require("__test__.bench.explorer.metrics")
local record

t:test("bulk Move preserves every file and unsaved buffer", function()
  local path = assert(vim.uv.fs_realpath(fixture.directory()))
  assert(vim.uv.fs_mkdir(path .. "/dst", 448))
  assert(vim.uv.fs_mkdir(path .. "/unrelated", 448))
  for index = 1, count do
    fixture.write(string.format("%s/file-%04d", path, index))
  end
  local opened = {}
  for index = 1, buffer_count do
    local moving = index <= math.min(count, math.floor(buffer_count / 2))
    local name = string.format(moving and "%s/file-%04d" or "%s/unrelated/file-%04d", path, index)
    if not moving then
      fixture.write(name)
    end
    local bufnr = vim.fn.bufadd(name)
    vim.fn.bufload(bufnr)
    t:defer(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end)
    local content = "unsaved-" .. index
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { content })
    opened[#opened + 1] = {
      bufnr = bufnr,
      content = content,
      target = moving and string.format("%s/dst/file-%04d", path, index) or name,
    }
  end
  t:patch_table(require("era.m.git.state"), "refresh", function()
    return stl.c.Future.resolve(nil)
  end)
  local requests, notifications = 0, 0
  t:patch_table(vim.lsp, "get_clients", function(options)
    if mode == "none" or (options and options.bufnr) then
      return {}
    end
    return {
      {
        name = "benchmark",
        offset_encoding = "utf-16",
        supports_method = function(_, method)
          return method == "workspace/didRenameFiles" or (mode == "async" and method == "workspace/willRenameFiles")
        end,
        request = function(_, method, params, done)
          assert(method == "workspace/willRenameFiles" and #params.files == 1)
          requests = requests + 1
          vim.schedule(function()
            done(nil, nil)
          end)
          return true, requests
        end,
        notify = function(_, method, params)
          assert(method == "workspace/didRenameFiles" and #params.files == 1)
          notifications = notifications + 1
          return true
        end,
      },
    }
  end)
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local nodes = {}
  for index = 1, count do
    nodes[index] = await(session.data:resolve(string.format("%s/file-%04d", path, index))):node()
  end
  local target = await(session.data:resolve(path .. "/dst"))
  -- Isolate editor/Job cost from display and watcher refresh.
  widget:hide()
  t.wait_until(function()
    return session.data:watch_status().roots == 0 and not session.data._native:is_busy()
  end, 10000)
  await(session.state:select_node(nodes, true))
  -- Preparation includes asynchronous waits; callback time overlaps preparation and synchronization.
  local metrics = { prepare_ms = 0, prepare_calls = 0, sync_ms = 0, sync_calls = 0, callbacks_ms = 0 }
  local prepare, sync, track = buffers.prepare, buffers.sync, session.data._track_job
  t:patch_table(buffers, "prepare", function(...)
    local start = vim.uv.hrtime()
    local future = prepare(...)
    future:finally(function()
      metrics.prepare_calls = metrics.prepare_calls + 1
      metrics.prepare_ms = metrics.prepare_ms + (vim.uv.hrtime() - start) / 1000000
    end)
    return future
  end)
  t:patch_table(buffers, "sync", function(...)
    local start = vim.uv.hrtime()
    local result = sync(...)
    metrics.sync_calls = metrics.sync_calls + 1
    metrics.sync_ms = metrics.sync_ms + (vim.uv.hrtime() - start) / 1000000
    return result
  end)
  local terminal
  t:patch_table(session.data, "_track_job", function(self, job, observer)
    return track(self, job, function(status)
      if status.terminal then
        terminal = terminal or vim.uv.hrtime()
      end
      local start = vim.uv.hrtime()
      observer(status)
      metrics.callbacks_ms = metrics.callbacks_ms + (vim.uv.hrtime() - start) / 1000000
    end)
  end)
  -- Detailed wrappers add overhead and are measured separately from the ordinary timing runs.
  if profiling then
    for _, item in ipairs({
      { object = vim.api, name = "nvim_list_bufs" },
      { object = yoz.fs, name = "entry_path" },
      { object = yoz.fs, name = "path_suffix" },
    }) do
      local original = item.object[item.name]
      local field = { calls = 0, ms = 0 }
      metrics[item.name] = field
      t:patch_table(item.object, item.name, function(...)
        local start = vim.uv.hrtime()
        local value, reason = original(...)
        field.calls = field.calls + 1
        field.ms = field.ms + (vim.uv.hrtime() - start) / 1000000
        return value, reason
      end)
    end
  end
  collectgarbage("collect")
  local usage = Metrics.usage()
  local start = vim.uv.hrtime()
  local job = await(session:operate(view, { kind = "move", target = target }))
  t.wait_until(function()
    return not session:busy() and not session.state:status().locked and not session.data._native:is_busy()
  end, 60000)
  local finished = vim.uv.hrtime()
  local after = Metrics.usage()
  record = {
    schema_version = 1,
    files = count,
    buffers = buffer_count,
    lsp = mode,
    profiling = profiling,
    wall_ms = (finished - start) / 1000000,
    terminal_ms = (assert(terminal) - start) / 1000000,
    delivery_tail_ms = (finished - terminal) / 1000000,
    cpu_ms = (after.cpu_us - usage.cpu_us) / 1000,
    main_cpu_ms = usage.main_us and (after.main_us - usage.main_us) / 1000,
    metrics = vim.deepcopy(metrics),
  }
  t.assert_eq(count, metrics.prepare_calls)
  t.assert_eq(count, metrics.sync_calls)
  t.assert_eq(count, session._counts.success)
  t.assert_eq(0, session._counts.failed)
  t.assert_eq(0, session._counts.editor_failed)
  t.assert_eq(count, job:status().results)
  t.assert_nil(job:status().error)
  t.assert_eq(mode == "async" and count or 0, requests)
  t.assert_eq(mode == "none" and 0 or count, notifications)
  for index = 1, count do
    t.assert_nil(vim.uv.fs_stat(string.format("%s/file-%04d", path, index)))
    t.assert_eq("test", vim.fn.readfile(string.format("%s/dst/file-%04d", path, index))[1])
  end
  for _, item in ipairs(opened) do
    t.assert_eq(item.target, vim.api.nvim_buf_get_name(item.bufnr))
    t.assert_eq(item.content, vim.api.nvim_buf_get_lines(item.bufnr, 0, -1, false)[1])
    t.assert_true(vim.api.nvim_get_option_value("modified", { buf = item.bufnr }))
  end
end)
local result = t:run({ exit = false, quiet = true })
assert(result.failed == 0, table.concat(result.failures, "\n"))
io.write(vim.json.encode(record) .. "\n")
