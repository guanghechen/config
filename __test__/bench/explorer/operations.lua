---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.operations" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local harness = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
package.path = harness .. "/?.lua;" .. package.path
local repo, directory, implementation, kind = assert(arg[1]), assert(arg[2]), assert(arg[3]), assert(arg[4])
local entries, repeats = assert(tonumber(arg[5])), assert(tonumber(arg[6]))
local bytes, files = tonumber(arg[7]) or 0, tonumber(arg[8]) or 0
local options = arg[9] and vim.json.decode(arg[9]) or {}
options.files = files
assert(kind == "git" or kind == "copy")
local ui = require("__test__.support.ui").new({ timeout_ms = 65000 })
local active
local failure
ui.on_notification = function(method, args)
  if (method == "explorer_bench_operation" or method == "explorer_bench_phase") and active then
    active.status = args[1]
  elseif method == "explorer_bench_error" then
    failure = args[1]
  end
end
local grid = require("__test__.support.ui_grid").new(ui, function(screen)
  if active and active.browse then
    if active.browse == "tree" then
      if not active.first_children and screen:find("file-") then
        active.first_children = vim.uv.hrtime()
      end
      if not active.first_item and screen:find("file-00000.lua") then
        active.first_item = vim.uv.hrtime()
      end
    end
    return
  end
  if active and kind == "copy" and not active.visible and screen:find("zz-copied") then
    active.visible = vim.uv.hrtime()
  end
end)

local ok, result = xpcall(function()
  ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
  local baseline = ui:rpc(
    "nvim_exec_lua",
    [[
      local file, repo, directory, implementation, kind, entries = ...
      local baseline = assert(loadfile(file))(repo, directory, implementation, entries, 0, "tree", { git = kind == "git" })
      bench.on_operation = function(status) vim.rpcnotify(1, "explorer_bench_operation", status) end
      bench.on_phase = function(status) vim.rpcnotify(1, "explorer_bench_phase", status) end
      bench.on_error = function(error) vim.rpcnotify(1, "explorer_bench_error", error) end
      assert(#bench.errors == 0, vim.inspect(bench.errors))
      return baseline
    ]],
    { here .. "/runtime.lua", repo, directory, implementation, kind, entries }
  )
  ---@param phase                         string
  ---@param rows                          integer
  ---@return nil
  local function prepare(phase, rows)
    active = {}
    ui:rpc("nvim_exec_lua", "bench.start(...)", { phase, rows })
    assert(
      vim.wait(30000, function()
        assert(not failure, failure)
        return active.status and active.status.done
      end, 5),
      "copy/Git setup did not finish: " .. phase
    )
    active = nil
  end
  prepare("open", entries)
  if kind == "git" then
    -- Ignore collection is viewport-driven; show the ignored fixture before timing either renderer.
    ui:rpc("nvim_exec_lua", "bench.reset_cursor(1)", {})
    ui:rpc("nvim_command", "redraw!")
    local deadline = vim.uv.hrtime() + 10000000000
    local ignored = false
    repeat
      ignored = ui:rpc("nvim_exec_lua", "return require('era.m.git.state').is_ignored(...)", {
        directory .. "/a-ignored.lua",
      })
      if ignored then
        break
      end
      vim.wait(10, function()
        return false
      end, 10)
    until vim.uv.hrtime() >= deadline
    assert(ignored, "visible ignored fixture did not settle")
  end
  local open_memory = options.memory_stages and ui:rpc("nvim_exec_lua", "return bench.memory()", {}) or nil
  if options.expanded or options.memory_stages then
    assert(kind == "copy" and files > 1)
    prepare("expand", entries + files)
    if options.memory_stages and not options.expanded then
      prepare("collapse", entries)
    end
    -- Loaded children can advance selection stamps after the expected rows appear.
    assert(
      vim.wait(30000, function()
        return ui:rpc(
          "nvim_exec_lua",
          [[
            if not bench.ready() then return false end
            if bench.implementation ~= "native" then return true end
            return bench.current_view():frame():header().selection_revision
              == bench.widget._session.state:status().revisions.selection
          ]],
          {}
        )
      end, 5),
      "copy source selection did not settle"
    )
  end
  local output = ui:rpc(
    "nvim_exec_lua",
    [[
      local file, directory, implementation, kind, entries, options = ...
      return assert(loadfile(file))(directory, implementation, kind, entries, options)
    ]],
    { here .. "/operations_runtime.lua", directory, implementation, kind, entries, options }
  )
  output.baseline, output.open_memory = baseline, open_memory or output.open_memory
  output.schema_version, output.scope, output.mode, output.implementation = 2, kind, "tree", implementation
  output.operations = {}
  for index = 1, kind == "git" and repeats * 2 or 1 do
    active = {}
    -- Append after the cursor anchor so both renderers can display the result without scrolling.
    local destination = options.destination or (files > 1 and "zz-copied/" or "zz-copied.bin")
    ui:rpc(
      "nvim_exec_lua",
      "bench.run_operation(...)",
      { kind == "git" and index % 2 == 1 or kind == "copy" and destination or false }
    )
    local sequence = ui._sequence
    local status
    local finished = vim.wait(60000, function()
      assert(not failure, failure)
      status = active.status
      return status and status.done and (kind == "git" or options.expanded or options.outside or active.visible)
    end, 10)
    if not finished then
      error(
        "operation did not finish: "
          .. kind
          .. ": "
          .. vim.inspect(ui:rpc("nvim_exec_lua", "return bench.operation_status()", {}))
      )
    end
    local operation = {
      kind = kind == "git" and "git_refresh" or "copy",
      ready_ms = (status.done - status.started) / 1000000,
      visible_ms = not options.expanded
          and not options.outside
          and active.visible
          and (active.visible - status.started) / 1000000
        or nil,
      query_ms = status.query_at and (status.query_at - status.started) / 1000000 or nil,
      job_ms = status.io_at and (status.io_at - status.started) / 1000000 or nil,
      cpu_ms = status.cpu_ms,
      main_cpu_ms = status.main_cpu_ms,
      job_cpu_ms = status.job_cpu_ms,
      job_main_cpu_ms = status.job_main_cpu_ms,
      selection_unlocked_ms = status.selection_unlocked_at
        and (status.selection_unlocked_at - status.started) / 1000000,
      session_idle_ms = status.session_idle_at and (status.session_idle_at - status.started) / 1000000,
      frame_ready_ms = status.frame_ready_at and (status.frame_ready_at - status.started) / 1000000,
      readiness_checks = status.readiness_checks,
      observer_rpcs = ui._sequence - sequence,
      max_tick_gap_ms = status.max_tick_gap_ms,
    }
    if kind == "copy" then
      if implementation == "native" then
        for _, key in ipairs({ "selection_unlocked_ms", "session_idle_ms", "frame_ready_ms" }) do
          assert(operation[key] and operation[key] >= operation.job_ms and operation[key] <= operation.ready_ms, key)
        end
      end
      operation.bytes, operation.files = bytes, files
      operation.mib_per_second = bytes / 1048576 / (operation.job_ms / 1000)
      operation.files_per_second = files / (operation.job_ms / 1000)
    end
    output.operations[#output.operations + 1] = operation
    active = nil
  end
  if options.memory_stages then
    output.memory_stages = ui:rpc(
      "nvim_exec_lua",
      "return { source_loaded = bench.source_memory, terminal_job_held = bench.terminal_memory, ready_job_held = bench.memory() }",
      {}
    )
  end
  ui:rpc("nvim_exec_lua", "bench.copy_job = nil", {})
  output.final_memory = ui:rpc("nvim_exec_lua", "return bench.memory()", {})
  if options.destination_browse then
    assert(implementation == "native" and not options.memory_stages)
    ui:rpc("nvim_exec_lua", "bench.reset_cursor(2)", {})
    assert(
      vim.wait(5000, function()
        return ui:rpc("nvim_exec_lua", "return bench.cursor_ready(2)", {})
      end, 1),
      "destination cursor did not settle"
    )
    ui:rpc("nvim_command", "redraw!")
    active = { browse = options.destination_browse }
    ui:rpc("nvim_exec_lua", "bench.browse_destination(...)", { options.destination_browse })
    local sequence = ui._sequence
    assert(
      vim.wait(60000, function()
        assert(not failure, failure)
        return active.status
          and active.status.done
          and (active.browse == "list" or active.first_children and active.first_item)
      end, 10),
      "copied destination did not become browsable"
    )
    local status = active.status
    output.destination_browse = {
      mode = options.destination_browse,
      ready_ms = (status.done - status.started) / 1000000,
      first_children_ms = active.first_children and (active.first_children - status.started) / 1000000 or nil,
      first_item_ms = active.first_item and (active.first_item - status.started) / 1000000 or nil,
      cpu_ms = status.cpu_ms,
      main_cpu_ms = status.main_cpu_ms,
      max_tick_gap_ms = status.max_tick_gap_ms,
      readiness_checks = status.readiness_checks,
      observer_rpcs = ui._sequence - sequence,
    }
    output.browsed_memory = ui:rpc("nvim_exec_lua", "return bench.memory()", {})
    active = nil
  end
  output.checks = kind == "git"
      and { actual_collection = true, changed_status_published = true, ignored_and_untracked = true }
    or {
      copy_finished = true,
      source_expanded = options.expanded == true,
      destination_outside_view = options.outside == true,
      content_verification = "runner compares source and destination after timing",
    }
  if options.memory_stages then
    output.memory_stages.job_released = output.final_memory
    output.memory_stages.hidden = ui:rpc("nvim_exec_lua", "return bench.hide_memory()", {})
    output.memory_stages.disposed_owner_held = ui:rpc(
      "nvim_exec_lua",
      [[
        bench.dispose()
        bench.widget, bench.phase = nil, nil
        local memory = bench.memory()
        memory.retained = bench.retained_native:stats()
        memory.reachable = bench.reachable_memory_refs()
        return memory
      ]],
      {}
    )
    output.memory_stages.disposed_owner_held_after_trace_flush = ui:rpc(
      "nvim_exec_lua",
      [[
        -- The preceding snapshot retains normal JIT behavior; this one isolates the native owner.
        jit.flush()
        assert(vim.wait(10000, function()
          collectgarbage("collect")
          for name in pairs(bench.memory_refs) do
            if name ~= "native" then return false end
          end
          return not bench.retained_native:is_busy() and bench.retained_native:stats().queue_depth == 0
        end, 10), "disposed Lua owners remained reachable after trace collection")
        local memory = bench.memory()
        memory.retained = bench.retained_native:stats()
        memory.reachable = bench.reachable_memory_refs()
        return memory
      ]],
      {}
    )
    output.memory_stages.released = ui:rpc(
      "nvim_exec_lua",
      [[
        bench.retained_native = nil
        assert(vim.wait(10000, function()
          collectgarbage("collect")
          return next(bench.memory_refs) == nil
        end, 10), "disposed copy session/data/view remained reachable")
        local memory = bench.memory()
        memory.reachable = bench.reachable_memory_refs()
        return memory
      ]],
      {}
    )
  else
    ui:rpc("nvim_exec_lua", "bench.dispose()", {})
  end
  return output
end, debug.traceback)
ui:close()
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
