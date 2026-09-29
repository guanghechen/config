---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.idle" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local harness = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
local root = vim.env.NVIM_EXPLORER_BENCH_CHECKOUT or harness
local Metrics = assert(loadfile(here .. "/metrics.lua"))()
local baseline = arg[1] and arg[1] ~= "-" and assert(vim.uv.fs_realpath(arg[1])) or nil
local samples = tonumber(arg[2]) or 3
assert(arg[3] == nil and samples >= 1 and samples <= 100 and samples % 1 == 0)
package.path = harness .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local UI = require("__test__.support.ui")
local directory = vim.fn.tempname()
assert(vim.uv.fs_mkdir(directory, 448))
local ui

local ok, result = xpcall(function()
  for index = 1, 200 do
    local path = string.format("%s/file-%05d.lua", directory, index)
    local fd = assert(vim.uv.fs_open(path, "wx", 384))
    assert(vim.uv.fs_close(fd))
  end
  local records = {}
  for trial = 1, samples do
    local order = baseline and (trial % 2 == 1 and { "legacy", "native" } or { "native", "legacy" }) or { "native" }
    for _, implementation in ipairs(order) do
      local checkout = implementation == "native" and root or baseline
      ui = UI.new({ timeout_ms = 15000 })
      ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
      ui:rpc(
        "nvim_exec_lua",
        [[
        local runtime, checkout, directory, implementation = ...
        assert(loadfile(runtime))(checkout, directory, implementation, 200, 0, "tree")
        bench.start("open", 200)
        assert(vim.wait(10000, function() return bench.phase and bench.phase.done end, 1))
        bench.timer:stop()
        bench.timer:close()
        bench.timer = nil
      ]],
        { here .. "/runtime.lua", checkout, directory, implementation }
      )
      for _, phase in ipairs({ "visible", "hidden", "disposed" }) do
        ui:rpc(
          "nvim_exec_lua",
          [[
          local phase, native = ...
          if phase == "hidden" then
            bench.widget:hide()
            if native then
              assert(vim.wait(10000, function()
                local session = bench.widget._session
                return session.data:watch_status().directories == 0
                  and not session.data._native:is_busy()
                  and session.data._native:stats().queue_depth == 0
              end, 1))
            end
          elseif phase == "disposed" then
            bench.widget:dispose()
            bench.widget = nil
          end
          collectgarbage("collect")
        ]],
          { phase, implementation == "native" }
        )
        vim.wait(500, function()
          return false
        end, 50)
        local before = ui:rpc(
          "nvim_exec_lua",
          [[
          local usage = vim.uv.getrusage()
          return { at = vim.uv.hrtime(), cpu_us = (usage.utime.sec + usage.stime.sec) * 1000000
            + usage.utime.usec + usage.stime.usec }
        ]],
          {}
        )
        local redraws = ui.redraws
        vim.wait(3000, function()
          return false
        end, 50)
        local after = ui:rpc(
          "nvim_exec_lua",
          [[
          local usage = vim.uv.getrusage()
          return { at = vim.uv.hrtime(), cpu_us = (usage.utime.sec + usage.stime.sec) * 1000000
            + usage.utime.usec + usage.stime.usec, process_memory_bytes = vim.uv.resident_set_memory(), errors = bench.errors }
        ]],
          {}
        )
        assert(#after.errors == 0, vim.inspect(after.errors))
        local wall_ms = (after.at - before.at) / 1000000
        local cpu_ms = (after.cpu_us - before.cpu_us) / 1000
        records[#records + 1] = {
          implementation = implementation,
          trial = trial,
          phase = phase,
          wall_ms = wall_ms,
          cpu_ms = cpu_ms,
          one_core_percent = cpu_ms / wall_ms * 100,
          redraw_notifications = ui.redraws - redraws,
          process_memory_mib = after.process_memory_bytes / 1048576,
        }
        io.stderr:write("Completed ", implementation, " ", phase, " in sample ", trial, "\n")
      end
      ui:close()
      ui = nil
    end
  end
  return {
    records = records,
    nvim = vim.version(),
    memory_measurement = Metrics.memory_description(),
    current = root,
    baseline = baseline,
    samples = samples,
    conditions = "Actual Widget; release native module; 200 empty Lua files; 110x40 attached UI; fresh processes per implementation in alternating order. Three idle phases, each after 500 ms settling and full GC, then 3 s with no parent polling. Benchmark timer stopped; Git collection and LSP disabled; process CPU includes all native threads.",
  }
end, debug.traceback)
if ui then
  ui:close()
end
vim.fn.delete(directory, "rf")
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
