---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.activity" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local harness = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
local root = vim.env.NVIM_EXPLORER_BENCH_CHECKOUT or harness
local Metrics = assert(loadfile(here .. "/metrics.lua"))()
local kind, samples = arg[1] or "jobs", tonumber(arg[2]) or 3
assert(
  (kind == "jobs" or kind == "jobs-many" or kind == "watch") and samples >= 1 and samples <= 100 and samples % 1 == 0
)
assert(arg[5] == nil)
local variant = {
  library = arg[3] and assert(vim.uv.fs_realpath(arg[3])) or nil,
  lua_root = arg[4] and assert(vim.uv.fs_realpath(arg[4])) or nil,
}
package.path = harness .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local UI = require("__test__.support.ui")
local Grid = require("__test__.support.ui_grid")
local directory, ui = vim.fn.tempname(), nil
assert(vim.uv.fs_mkdir(directory, 448))

---@param path                          string
---@param bytes                         ?integer
---@return nil
local function file(path, bytes)
  local descriptor = assert(vim.uv.fs_open(path, "wx", 384))
  if bytes then
    assert(vim.uv.fs_ftruncate(descriptor, bytes))
  end
  assert(vim.uv.fs_close(descriptor))
end

local setup = [=[
  local variant = ...
  bench.timer:stop()
  bench.timer:close()
  bench.timer = nil
  local ffi
  if vim.uv.os_uname().sysname == "Darwin" then
    ffi = require("ffi")
    ffi.cdef[[
      void *pthread_self(void);
      unsigned int pthread_mach_thread_np(void *thread);
      int thread_info(unsigned int thread, int flavor, int *info, unsigned int *count);
    ]]
  end
  ---@return table
  function bench.usage()
    local usage = vim.uv.getrusage()
    local value = { at = vim.uv.hrtime(), cpu_us = (usage.utime.sec + usage.stime.sec) * 1000000
      + usage.utime.usec + usage.stime.usec }
    if ffi then
      local info, count = ffi.new("int[10]"), ffi.new("unsigned int[1]", 10)
      assert(ffi.C.thread_info(ffi.C.pthread_mach_thread_np(ffi.C.pthread_self()), 3, info, count) == 0)
      value.main_us = (tonumber(info[0]) + tonumber(info[2])) * 1000000 + tonumber(info[1]) + tonumber(info[3])
    end
    return value
  end
  ---@param future                      stl.c.Future
  ---@return any
  function bench.await(future)
    assert(vim.wait(15000, function() return future:is_done() end, 1))
    assert(not future:is_failed(), future:get_error())
    local result = future:get_result()
    assert(type(result) ~= "table" or result.kind ~= "Rejected", vim.inspect(result))
    return result
  end
  local owner = bench.widget._session.data._tree
  local poll = owner._poll
  owner._poll = function(self)
    if bench.activity then bench.activity.owner_polls = bench.activity.owner_polls + 1 end
    return poll(self)
  end
  local jobs = require("era.m.explorer.jobs")
  bench.module_sources = { jobs = debug.getinfo(jobs.start, "S").source,
    filetree = debug.getinfo(bench.widget._session.data._track_job, "S").source,
    filetree_observer = debug.getinfo(bench.widget._session.data._poll
      or bench.widget._session._subscriptions._poll_before, "S").source }
  if variant.lua_root then
    for _, source in pairs(bench.module_sources) do
      assert(source:find("@" .. variant.lua_root .. "/", 1, true) == 1, "unexpected module: " .. source)
    end
  end
  if jobs._poll then
    local poll = jobs._poll
    jobs._poll = function()
      if bench.activity then bench.activity.job_polls = bench.activity.job_polls + 1 end
      return poll()
    end
  end
  ---@return nil
  function bench.begin()
    collectgarbage("collect")
    local activity = { before = bench.usage(), owner_polls = 0, job_polls = 0, max_tick_gap_ms = 0 }
    local last = vim.uv.hrtime()
    activity.last_tick = last
    activity.timer = assert(vim.uv.new_timer())
    activity.timer:start(5, 5, vim.schedule_wrap(function()
      if bench.activity ~= activity then return end
      local now = vim.uv.hrtime()
      activity.max_tick_gap_ms = math.max(activity.max_tick_gap_ms, (now - last) / 1000000)
      last = now
      activity.last_tick = now
    end))
    bench.activity = activity
  end
  ---@return table
  function bench.finish()
    local activity, after = assert(bench.activity), bench.usage()
    bench.activity = nil
    activity.max_tick_gap_ms = math.max(activity.max_tick_gap_ms, (after.at - activity.last_tick) / 1000000)
    activity.timer:stop()
    activity.timer:close()
    local wall_ms = (after.at - activity.before.at) / 1000000
    local cpu_ms = (after.cpu_us - activity.before.cpu_us) / 1000
    local main_ms = after.main_us and (after.main_us - activity.before.main_us) / 1000
    return { wall_ms = wall_ms, cpu_ms = cpu_ms, cpu_percent = cpu_ms / wall_ms * 100,
      main_cpu_ms = main_ms, main_cpu_percent = main_ms and main_ms / wall_ms * 100,
      owner_polls = activity.owner_polls, job_polls = activity.job_polls,
      max_tick_gap_ms = activity.max_tick_gap_ms, module_sources = bench.module_sources, errors = bench.errors }
  end
]=]

local ok, result = xpcall(function()
  local records = {}
  for trial = 1, samples do
    local path = directory .. "/" .. trial
    assert(vim.uv.fs_mkdir(path, 448))
    local rows = kind ~= "watch" and 2 or 1002
    if kind == "jobs" then
      file(path .. "/file-00001.bin", 256 * 1024 * 1024)
      assert(vim.uv.fs_mkdir(path .. "/dst", 448))
    elseif kind == "jobs-many" then
      assert(vim.uv.fs_mkdir(path .. "/src", 448))
      assert(vim.uv.fs_mkdir(path .. "/dst", 448))
      for index = 1, 1000 do
        file(string.format("%s/src/file-%05d", path, index), 4)
      end
    else
      for index = 1, 1000 do
        file(string.format("%s/file-%05d", path, index))
      end
      file(path .. "/aaa-anchor")
      file(path .. "/aaa-event-00000")
    end
    ui = UI.new({ timeout_ms = 45000 })
    local changes = {}
    Grid.new(ui, function(screen)
      if kind ~= "watch" then
        return
      end
      local position = screen:find("aaa-event-")
      if not position then
        return
      end
      local cells = screen.grids[position.grid].rows[position.row + 1]
      local number = ""
      for offset = 1, 5 do
        number = number .. cells[position.col + 10 + offset][1]
      end
      local change = changes[tonumber(number)]
      if change and not change.seen then
        change.seen = vim.uv.hrtime()
      end
    end)
    ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
    ui:rpc(
      "nvim_exec_lua",
      [[
        local runtime, root, directory, rows, variant = ...
        assert(loadfile(runtime))(root, directory, "native", rows, 0, "tree", variant)
        bench.start("open", rows)
      ]],
      { here .. "/runtime.lua", root, path, rows, variant }
    )
    assert(
      vim.wait(15000, function()
        local status = ui:rpc("nvim_exec_lua", "return bench.status()", {})
        assert(#status.errors == 0, vim.inspect(status.errors))
        return status.done
      end, 5),
      "Widget did not open"
    )
    ui:rpc("nvim_exec_lua", setup, { variant })
    vim.wait(300, function()
      return false
    end, 50)
    if kind ~= "watch" then
      ui:rpc(
        "nvim_exec_lua",
        [=[
        local directory, kind = ...
        local session, view = bench.widget:context()
        local source = bench.await(session.data:resolve(directory .. (kind == "jobs" and "/file-00001.bin" or "/src")))
        bench.await(session.state:dispatch({ kind = "set_cursor", node = source:node() }, { frame = view:frame() }))
        assert(vim.wait(5000, function()
          return view:frame():header().cursor_row == view:frame():position(source:node())
        end, 1))
        -- Preserved native snapshots used positional kind/options before the request API.
        local positional = debug.getinfo(session.operate, "u").nparams == 4
        local request = { kind = "copy_to_path", path = directory .. (kind == "jobs" and "/dst/file-00001.bin" or "/dst/copied"),
          on_complete = function(status)
            bench.activity_result = bench.finish()
            bench.activity_result.bytes = status.bytes
            bench.activity_result.job_error = status.error
            bench.activity_result.successes = session._counts.success
          end,
        }
        bench.begin()
        local copying = positional
          and session:operate(view, "copy", { to_path = request.path, on_complete = request.on_complete })
          or session:operate(view, request)
        copying:finally(function(ok, value)
          if not ok then bench.activity_error = tostring(value) end
        end)
      ]=],
        { path, kind }
      )
      local record
      assert(
        vim.wait(45000, function()
          local value =
            ui:rpc("nvim_exec_lua", "return { result = bench.activity_result, error = bench.activity_error }", {})
          assert(not value.error, value.error)
          record = value.result
          return record ~= nil
        end, 25),
        "copy timed out"
      )
      assert(#record.errors == 0 and not record.job_error, vim.inspect(record))
      local expected_bytes = kind == "jobs" and 256 * 1024 * 1024 or 4000
      assert(record.bytes == expected_bytes and record.successes == 1, vim.inspect(record))
      local destination = path .. (kind == "jobs" and "/dst/file-00001.bin" or "/dst/copied/file-01000")
      assert(vim.uv.fs_stat(destination).size == (kind == "jobs" and expected_bytes or 4))
      record.trial, record.kind = trial, kind == "jobs" and "copy_256_mib" or "copy_1000_files"
      records[#records + 1] = record
    else
      local sequence, previous = 0, "aaa-event-00000"
      ---@return table
      local function rename()
        sequence = sequence + 1
        local label = string.format("aaa-event-%05d", sequence)
        local change = { sequence = sequence, at = vim.uv.hrtime() }
        changes[sequence] = change
        assert(vim.uv.fs_rename(path .. "/" .. previous, path .. "/" .. label))
        previous = label
        return change
      end
      for _, scenario in ipairs({ "isolated", "continuous", "burst" }) do
        local first = sequence + 1
        ui:rpc("nvim_exec_lua", "bench.begin()", {})
        if scenario == "isolated" then
          for _ = 1, 20 do
            local change = rename()
            assert(
              vim.wait(10000, function()
                return change.seen ~= nil
              end, 1),
              "watch rename was not displayed"
            )
          end
        elseif scenario == "continuous" then
          for index = 1, 80 do
            file(string.format("%s/generated-%05d", path, index))
            rows = rows + 1
            rename()
            vim.wait(20, function()
              return false
            end, 5)
          end
        else
          for index = 1, 500 do
            file(string.format("%s/burst-%05d", path, index))
            rows = rows + 1
          end
          rename()
        end
        local caught_up = vim.wait(15000, function()
          return changes[sequence].seen ~= nil
        end, 1)
        if not caught_up then
          local state = ui:rpc(
            "nvim_exec_lua",
            [[
            local session, view = bench.widget:context()
            local header = view:frame():header()
            return { rows = header.row_count, cursor = header.cursor_row,
              first_lines = vim.api.nvim_buf_get_lines(view.bufnr, 0, 5, false),
              top = vim.api.nvim_win_call(view.winnr, function() return vim.fn.line('w0') end),
              watches = session.data:watch_status().directories, queue = session.data._native:stats().queue_depth }
          ]],
            {}
          )
          error("watch did not catch up: " .. scenario .. " " .. sequence .. " " .. vim.inspect(state), 0)
        end
        assert(
          vim.wait(15000, function()
            return ui:rpc(
              "nvim_exec_lua",
              [[
            local rows = ...
            local session, view = bench.widget:context()
            return view:frame():header().row_count == rows and not session.data._native:is_busy() and not view._busy
          ]],
              { rows }
            )
          end, 25),
          "watch did not publish all rows"
        )
        local record = ui:rpc("nvim_exec_lua", "return bench.finish()", {})
        assert(#record.errors == 0, vim.inspect(record.errors))
        record.trial, record.kind, record.changes, record.visible_ms = trial, scenario, sequence - first + 1, {}
        for index = first, sequence do
          local change = changes[index]
          if change.seen then
            record.visible_ms[#record.visible_ms + 1] = (change.seen - change.at) / 1000000
          end
        end
        record.final_change_ms = (changes[sequence].seen - changes[sequence].at) / 1000000
        records[#records + 1] = record
      end
    end
    ui:close()
    ui = nil
    vim.fn.delete(path, "rf")
    io.stderr:write("Completed ", kind, " sample ", trial, "\n")
  end
  return {
    records = records,
    nvim = vim.version(),
    memory_measurement = Metrics.memory_description(),
    current = root,
    variant = variant,
    conditions = "Actual Widget, 110x40 UI, release native module, fresh process per sample; Git/LSP collection disabled. Jobs copy either a 256 MiB sparse file or a directory with 1000 four-byte files; filesystem caches are warm. Watch uses 1000 initial files plus a stable cursor anchor and a visible rename marker, 20 isolated renames, 80 creations/renames 20 ms apart, and a burst of 500 creations. A 5 ms latency timer and parent RPC observation are included in CPU. CPU is percent of one core; main-thread CPU is available on macOS. The final tick-to-completion interval is included in the maximum gap. Continuous events may be coalesced; visible_ms contains only displayed versions, while final_change_ms measures catch-up. Watch phases run in the stated order.",
  }
end, debug.traceback)
if ui then
  ui:close()
end
vim.fn.delete(directory, "rf")
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
