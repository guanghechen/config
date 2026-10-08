---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.loading" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local harness = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
local root = vim.env.NVIM_EXPLORER_BENCH_CHECKOUT or harness
local Metrics = assert(loadfile(here .. "/metrics.lua"))()
package.path = harness .. "/?.lua;" .. package.path
local samples, entries = tonumber(arg[1]) or 3, tonumber(arg[2]) or 50000
assert(samples >= 1 and samples <= 100 and samples % 1 == 0)
assert(entries >= 2048 and entries <= 50000 and entries % 1 == 0 and arg[3] == nil)
local UI = require("__test__.support.ui")
local Grid = require("__test__.support.ui_grid")
local directory, ui = vim.fn.tempname(), nil
assert(vim.uv.fs_mkdir(directory, 448))
directory = assert(vim.uv.fs_realpath(directory))

---@param path                          string
---@return nil
local function file(path)
  local descriptor = assert(vim.uv.fs_open(path, "wx", 384))
  assert(vim.uv.fs_close(descriptor))
end

local setup = [=[
  bench.timer:stop()
  bench.loading_branch = bench.current_view():frame():node_at(1)
  bench.loading_timer = assert(vim.uv.new_timer())

  ---@param kind                        string
  ---@param value                       table|string
  ---@return nil
  local function send(kind, value)
    vim.rpcnotify(1, "explorer_loading", kind, value)
  end

  ---@return nil
  local function tick()
    local operation = bench.loading
    if not operation then return end
    assert(#bench.errors == 0, vim.inspect(bench.errors))
    local view, data = bench.current_view(), bench.widget._session.data
    local frame = view and view:frame()
    if not frame then return end
    local header = frame:header()
    local node = data:source():node(bench.loading_branch)
    assert(not node.error, vim.inspect(node.error))
    local now = vim.uv.hrtime()
    operation.max_tick_gap_ms = math.max(operation.max_tick_gap_ms, (now - operation.last_tick) / 1000000)
    operation.last_tick = now
    if operation.stage == "waiting" then
      if node.load_state ~= "loading" or header.row_count < 4 or view._busy
        or not view._state._native:applicable(frame) then return end
      local row = vim.api.nvim_win_get_cursor(view.winnr)[1]
      local target = assert(frame:node_at(row + 1))
      operation.target = target
      operation.started = now
      operation.children_at_input = node.child_count
      operation.stage = "cursor"
      send("cursor_start", { started = now, label = frame:source():node(target).label })
      assert(vim.api.nvim_input("j") == 1)
    elseif operation.stage == "cursor" then
      if header.cursor ~= operation.target or header.cursor_row ~= vim.api.nvim_win_get_cursor(view.winnr)[1] then return end
      assert(node.load_state == "loading", "cursor was applied only after loading ended")
      operation.stage = "cursor_done"
      send("cursor_done", {
        input_ms = (now - operation.started) / 1000000,
        children_at_input = operation.children_at_input,
        children_at_cursor = node.child_count,
        max_tick_gap_ms = operation.max_tick_gap_ms,
      })
    elseif operation.stage == "cancel" then
      if header.mode ~= "tree" or header.row_count ~= 2 or not data._native:is_settled() or view._busy then return end
      assert(node.load_state ~= "loading", "hidden branch still owns a read")
      if operation.phase == "cold" then
        assert(node.child_count < operation.entries, "cold scan finished before cancellation")
      end
      operation.stage = "cancel_done"
      send("cancel_done", {
        cancel_ms = (now - operation.cancel_started) / 1000000,
        children_at_cancel = operation.children_at_cancel,
        retained_children = node.child_count,
        max_tick_gap_ms = operation.max_tick_gap_ms,
      })
    elseif operation.stage == "resume" then
      local ready, rows = bench.ready()
      if not ready or rows ~= operation.entries + 2 then return end
      assert(node.completeness == "complete" and node.child_count == operation.entries)
      operation.stage = "done"
      bench.loading_timer:stop()
      send("resume_done", { resume_ms = (now - operation.resume_started) / 1000000 })
    end
  end

  ---@param mode                        string
  ---@param phase                       string
  ---@param count                       integer
  ---@return nil
  function bench.loading_begin(mode, phase, count)
    local now = vim.uv.hrtime()
    bench.loading = { mode = mode, phase = phase, entries = count, stage = "waiting",
      last_tick = now, max_tick_gap_ms = 0 }
    bench.loading_timer:start(2, 2, vim.schedule_wrap(function()
      local ok, error = xpcall(tick, debug.traceback)
      if not ok then
        bench.loading_timer:stop()
        send("error", error)
      end
    end))
    vim.api.nvim_input(phase == "warm" and "R" or mode == "tree" and "l" or "t2")
  end

  ---@return nil
  function bench.loading_cancel()
    local operation = bench.loading
    assert(operation.stage == "cursor_done")
    local node = bench.widget._session.data:source():node(bench.loading_branch)
    assert(node.load_state == "loading", "scan ended before the cancellation input")
    operation.cancel_started = vim.uv.hrtime()
    operation.children_at_cancel = node.child_count
    operation.stage = "cancel"
    send("cancel_start", { started = operation.cancel_started })
    vim.api.nvim_input(operation.mode == "tree" and "h" or "t2")
  end

  ---@return nil
  function bench.loading_resume()
    local operation = bench.loading
    assert(operation.stage == "cancel_done")
    local view = bench.current_view()
    assert(view:frame():header().row_count == 2)
    operation.stage = "resume"
    operation.resume_started = vim.uv.hrtime()
    vim.api.nvim_win_set_cursor(view.winnr, { 1, 0 })
    vim.api.nvim_input(operation.mode == "tree" and "l" or "t2")
  end
]=]

local ok, result = xpcall(function()
  assert(vim.uv.fs_mkdir(directory .. "/a-branch", 448))
  file(directory .. "/file-00000.lua")
  for index = 1, entries do
    file(string.format("%s/a-branch/inside-%05d.lua", directory, index))
  end
  local records = {}
  for trial = 1, samples do
    for _, mode in ipairs({ "tree", "list" }) do
      ui = UI.new({ timeout_ms = 90000 })
      local active, failure
      ui.on_notification = function(method, args)
        if method ~= "explorer_loading" then
          return
        end
        if args[1] == "error" then
          failure = args[2]
        elseif active then
          active[args[1]] = args[2]
        end
      end
      Grid.new(ui, function(grid)
        if not active then
          return
        end
        if active.cursor_start and not active.input_visible_ms then
          local target = grid:find(active.cursor_start.label)
          if target and grid.cursor and grid.cursor[1] == target.grid and grid.cursor[2] == target.row then
            active.input_visible_ms = (vim.uv.hrtime() - active.cursor_start.started) / 1000000
          end
        end
        if
          active.cancel_start
          and not active.cancel_visible_ms
          and grid:find("a-branch")
          and not grid:find("inside-")
        then
          active.cancel_visible_ms = (vim.uv.hrtime() - active.cancel_start.started) / 1000000
        end
      end)
      ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
      ui:rpc(
        "nvim_exec_lua",
        [[
        local runtime, root, directory, count = ...
        assert(loadfile(runtime))(root, directory, "native", 1, count, "tree")
        bench.start("open", 2)
      ]],
        { here .. "/runtime.lua", root, directory, entries }
      )
      assert(
        vim.wait(30000, function()
          return ui:rpc("nvim_exec_lua", "return bench.phase and bench.phase.done ~= nil", {})
        end, 20),
        "initial root did not settle"
      )
      ui:rpc("nvim_exec_lua", setup, {})
      for _, phase in ipairs({ "cold", "warm" }) do
        ui:rpc("nvim_exec_lua", "bench.reset_cursor(1)", {})
        assert(vim.wait(10000, function()
          return ui:rpc("nvim_exec_lua", "return bench.cursor_ready(1)", {})
        end, 10))
        active = {}
        ui:rpc("nvim_exec_lua", "bench.loading_begin(...)", { mode, phase, entries })
        local sequence = ui._sequence
        assert(
          vim.wait(60000, function()
            assert(not failure, failure)
            return active.cursor_done and active.input_visible_ms
          end, 2),
          "no visible cursor response during active loading"
        )
        local observer_rpcs = ui._sequence - sequence
        ui:rpc("nvim_exec_lua", "bench.loading_cancel()", {})
        sequence = ui._sequence
        assert(
          vim.wait(30000, function()
            assert(not failure, failure)
            return active.cancel_done and active.cancel_visible_ms
          end, 2),
          "cancelled loading did not retire its work and collapse the view"
        )
        observer_rpcs = observer_rpcs + ui._sequence - sequence
        ui:rpc("nvim_exec_lua", "bench.loading_resume()", {})
        sequence = ui._sequence
        assert(
          vim.wait(90000, function()
            assert(not failure, failure)
            return active.resume_done
          end, 2),
          "cancelled directory did not load completely on reopening"
        )
        observer_rpcs = observer_rpcs + ui._sequence - sequence
        records[#records + 1] = vim.tbl_extend("error", active.cursor_done, active.resume_done, {
          trial = trial,
          mode = mode,
          phase = phase,
          entries = entries,
          input_visible_ms = active.input_visible_ms,
          cancel_ms = active.cancel_done.cancel_ms,
          cancel_visible_ms = active.cancel_visible_ms,
          children_at_cancel = active.cancel_done.children_at_cancel,
          retained_children = active.cancel_done.retained_children,
          observer_rpcs = observer_rpcs,
        })
        assert(observer_rpcs == 0)
        active = nil
      end
      ui:rpc("nvim_exec_lua", "bench.loading_timer:close(); bench.dispose()", {})
      ui:close()
      ui = nil
    end
  end
  return {
    records = records,
    memory_measurement = Metrics.memory_description(),
    conditions = "Fresh native process per sample and mode; one shared warm filesystem fixture. Typed j is injected only while the branch reports Loading and the published frame is applicable. Cursor publication must finish during Loading; visible latency ends at the parent UI flush. Typed h (Tree) or t2 (List to Tree) must retire scan work, preserve the collapsed view, and allow a complete reopen. Cold expansion and warm refresh remain separate. Two-ms child checks, no readiness RPCs during measurement; acceptance only, not a legacy comparison or p95 claim.",
  }
end, debug.traceback)
if ui then
  ui:close()
end
vim.fn.delete(directory, "rf")
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
