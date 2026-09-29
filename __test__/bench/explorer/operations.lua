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
  if method == "explorer_bench_operation" and active then
    active.status = args[1]
  elseif method == "explorer_bench_error" then
    failure = args[1]
  end
end
local grid = require("__test__.support.ui_grid").new(ui, function(screen)
  if active and kind == "copy" and not active.visible and screen:find("zz-copied") then
    active.visible = vim.uv.hrtime()
  end
end)

local ok, result = xpcall(function()
  ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
  local output = ui:rpc(
    "nvim_exec_lua",
    [[
      local file, repo, directory, implementation, kind, entries, options = ...
      local output = assert(loadfile(file))(repo, directory, implementation, kind, entries, options)
      bench.on_operation = function(status) vim.rpcnotify(1, "explorer_bench_operation", status) end
      bench.on_error = function(error) vim.rpcnotify(1, "explorer_bench_error", error) end
      assert(#bench.errors == 0, vim.inspect(bench.errors))
      return output
    ]],
    { here .. "/operations_runtime.lua", repo, directory, implementation, kind, entries, options }
  )
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
      readiness_checks = status.readiness_checks,
      observer_rpcs = ui._sequence - sequence,
      max_tick_gap_ms = status.max_tick_gap_ms,
    }
    if kind == "copy" then
      operation.bytes, operation.files = bytes, files
      operation.mib_per_second = bytes / 1048576 / (operation.job_ms / 1000)
      operation.files_per_second = files / (operation.job_ms / 1000)
    end
    output.operations[#output.operations + 1] = operation
    active = nil
  end
  ui:rpc("nvim_exec_lua", "bench.copy_job = nil", {})
  output.final_memory = ui:rpc("nvim_exec_lua", "return bench.memory()", {})
  output.checks = kind == "git"
      and { actual_collection = true, changed_status_published = true, ignored_and_untracked = true }
    or {
      copy_finished = true,
      source_expanded = options.expanded == true,
      destination_outside_view = options.outside == true,
      content_verification = "runner compares source and destination after timing",
    }
  ui:rpc("nvim_exec_lua", "bench.dispose()", {})
  return output
end, debug.traceback)
ui:close()
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
