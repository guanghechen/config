---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.measure" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local support = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
package.path = support .. "/?.lua;" .. package.path
local repo, directory, implementation = assert(arg[1]), assert(arg[2]), assert(arg[3])
local entries, branch_entries = assert(tonumber(arg[4])), tonumber(arg[5]) or 0
local repeats = assert(tonumber(arg[6]))
local mode = assert(arg[7])
assert(implementation == "native" or implementation == "legacy")
assert(mode == "tree" or mode == "list")
local ui = require("__test__.support.ui").new({ timeout_ms = 65000 })
local active
local failure
ui.on_notification = function(method, args)
  if method == "explorer_bench_phase" and active then
    active.status = args[1]
  elseif method == "explorer_bench_error" then
    failure = args[1]
  end
end
local cursor_row = 1
local grid = require("__test__.support.ui_grid").new(ui, function(screen)
  if not active or active.first then
    return
  end
  local kind = active.kind
  local target = kind == "scroll" and screen:find(active.marker)
  local visible = kind == "open" and screen:find("file-")
    or kind == "reopen" and (screen:find("file-") or screen:find("inside-"))
    or kind == "expand" and screen:find("inside-")
    or kind == "collapse" and not screen:find("inside-") and screen:find("file-")
    or kind == "cursor" and screen.cursor and screen.cursor[2] == active.screen_row
    or target and screen.cursor and screen.cursor[1] == target.grid and screen.cursor[2] == target.row
  if visible then
    active.first = vim.uv.hrtime()
  end
end)

---@param kind                          string
---@param rows                          integer
---@param next_cursor                   ?integer
---@param selected                      ?integer
---@return table
local function measure(kind, rows, next_cursor, selected)
  active = { kind = kind }
  if kind == "cursor" then
    active.screen_row = grid.cursor[2] + next_cursor - cursor_row
  elseif kind == "scroll" then
    active.marker = ui:rpc("nvim_exec_lua", "return bench.row_marker(...)", { next_cursor })
  end
  ui:rpc("nvim_exec_lua", "bench.start(...)", { kind, rows, next_cursor or false, selected or false })
  local sequence = ui._sequence
  local completed
  local finished = vim.wait(60000, function()
    assert(not failure, failure)
    local value = active.status
    if
      value
      and value.done
      and (
        active.first
        or kind == "refresh"
        or kind == "empty_git_notification"
        or kind == "selection"
        or kind == "visual_selection"
      )
    then
      completed = {
        kind = kind,
        ready_ms = (value.done - value.started) / 1000000,
        visible_ms = active.first and (active.first - value.started) / 1000000 or nil,
        body_ms = value.body and (value.body - value.started) / 1000000 or nil,
        max_tick_gap_ms = value.max_tick_gap_ms,
        cpu_ms = value.cpu_ms,
        main_cpu_ms = value.main_cpu_ms,
        readiness_checks = value.readiness_checks,
        observer_rpcs = ui._sequence - sequence,
        target_row = next_cursor,
        selected_count = value.selected,
      }
      return true
    end
    return false
  end, 10)
  if not finished then
    error("timed out: " .. kind .. ": " .. vim.inspect(ui:rpc("nvim_exec_lua", "return bench.status()", {})))
  end
  if next_cursor then
    cursor_row = next_cursor
  end
  active = nil
  return completed
end

---@param row                           integer
---@return nil
local function position(row)
  ui:rpc("nvim_exec_lua", "bench.reset_cursor(...)", { row })
  assert(vim.wait(5000, function()
    return ui:rpc("nvim_exec_lua", "return bench.cursor_ready(...)", { row })
  end, 1))
  ui:rpc("nvim_command", "redraw!")
  cursor_row = row
end

local ok, result = xpcall(function()
  ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
  local baseline = ui:rpc(
    "nvim_exec_lua",
    [[
      local runtime, repo, directory, implementation, entries, branch, mode = ...
      local baseline = assert(loadfile(runtime))(repo, directory, implementation, entries, branch, mode)
      bench.on_phase = function(status) vim.rpcnotify(1, "explorer_bench_phase", status) end
      bench.on_error = function(error) vim.rpcnotify(1, "explorer_bench_error", error) end
      assert(#bench.errors == 0, vim.inspect(bench.errors))
      return baseline
    ]],
    { here .. "/runtime.lua", repo, directory, implementation, entries, branch_entries, mode }
  )
  local output = {
    schema_version = 2,
    implementation = implementation,
    mode = mode,
    entries = entries,
    branch_entries = branch_entries,
    baseline = baseline,
    operations = {},
  }
  local rows = entries + (branch_entries > 0 and 1 or 0) + (mode == "list" and branch_entries or 0)
  output.operations[#output.operations + 1] = measure("open", rows)
  output.open_memory = ui:rpc("nvim_exec_lua", "return bench.memory()", {})
  position(1)
  if branch_entries > 0 and mode == "tree" then
    output.operations[#output.operations + 1] = measure("expand", rows + branch_entries)
    for _ = 1, repeats do
      output.operations[#output.operations + 1] = measure("collapse", rows)
      output.operations[#output.operations + 1] = measure("expand", rows + branch_entries)
    end
    rows = rows + branch_entries
  end
  for index = 1, repeats * 2 do
    output.operations[#output.operations + 1] = measure("cursor", rows, index % 2 == 1 and 2 or 1)
  end
  for index = 1, repeats * 2 do
    output.operations[#output.operations + 1] = measure("scroll", rows, index % 2 == 1 and rows or 1)
  end
  position(rows)
  for index = 1, repeats * 2 do
    output.operations[#output.operations + 1] = measure("selection", rows, nil, index % 2 == 1 and 1 or 0)
  end
  local count = math.min(100, math.floor(rows / 2))
  for _ = 1, repeats do
    position(rows - count + 1)
    output.operations[#output.operations + 1] = measure("visual_selection", rows, nil, count)
    ui:rpc("nvim_exec_lua", "bench.clear_selection()", {})
  end
  position(1)
  for _ = 1, math.min(3, repeats) do
    output.operations[#output.operations + 1] = measure("refresh", rows)
  end
  for _ = 1, repeats do
    output.operations[#output.operations + 1] = measure("empty_git_notification", rows)
  end
  for _ = 1, repeats do
    ui:rpc("nvim_exec_lua", "bench.widget:hide()", {})
    ui:rpc("nvim_command", "redraw!")
    output.operations[#output.operations + 1] = measure("reopen", rows)
  end
  output.final_memory = ui:rpc("nvim_exec_lua", "return bench.memory()", {})
  ui:rpc("nvim_exec_lua", "bench.dispose()", {})
  return output
end, debug.traceback)
ui:close()
if not ok then
  error(result, 0)
end
io.stdout:write(vim.json.encode(result), "\n")
