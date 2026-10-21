---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.load" ---@type string

local Child = require("__test__.bench.cmp.child")
local M = {}

---@param scenario                      table
---@return table[]
local function input_plan(scenario)
  local plan = {}
  local query = scenario.seed or ""
  local keys = scenario.dense and { "t", "o", "n", "<BS>", "<BS>", "<BS>" }
    or { "e", "t", "C", "o", "<BS>", "<BS>", "<BS>", "<BS>" }
  if not scenario.seed then
    plan[1] = { keys = "ig", key = "g", query = "g", offset_ms = 0 }
    query = "g"
  end
  for _ = 1, scenario.hide and 1 or 4 do
    for _, key in ipairs(keys) do
      if scenario.hide and key == "<BS>" then
        break
      end
      query = key == "<BS>" and query:sub(1, -2) or query .. key
      plan[#plan + 1] = { keys = key, key = key, query = query, offset_ms = #plan * scenario.interval_ms }
    end
  end
  if scenario.hide then
    plan[#plan + 1] = { keys = "<Esc>", key = "<Esc>", query = query, offset_ms = #plan * scenario.interval_ms }
  end
  return plan
end

---@param ui                            __test__.support.UI
---@param recorder                      __test__.bench.cmp.IRecorder
---@param scenario                      table
---@param plan                          table[]
---@return table
local function burst(ui, recorder, scenario, plan)
  ui:rpc("nvim_input", "<Esc>")
  ui:wait_until(function()
    return ui:rpc("nvim_get_mode").mode == "n"
  end, 2000, "normal mode")
  ui:lua("require('__test__.bench.cmp.load_editor').prepare(...)", #plan)
  if scenario.seed then
    ui:rpc("nvim_input", "i" .. scenario.seed)
    ui:wait_until(function()
      return ui:lua("return require('__test__.bench.cmp.load_editor').ready()")
    end, 5000, "seed completion")
    vim.wait(25)
  end
  recorder.events = {}
  ui:lua("require('__test__.bench.cmp.load_editor').begin(...)", plan)
  local start = vim.uv.hrtime() + 20e6
  local sent, next_key = {}, 1
  local timer = assert(vim.uv.new_timer())
  -- The producer runs in the parent, so a blocked editor cannot postpone the offered load.
  timer:start(0, 1, function()
    while next_key <= #plan and vim.uv.hrtime() >= start + plan[next_key].offset_ms * 1e6 do
      local step = plan[next_key]
      sent[next_key] = { scheduled_ns = start + step.offset_ms * 1e6, sent_ns = vim.uv.hrtime() }
      ui:notify("nvim_input", step.keys)
      next_key = next_key + 1
    end
    if next_key > #plan then
      timer:stop()
    end
  end)
  local input_done, seen = nil, 0
  local pending_requests, last_response = {}, start
  local ok = vim.wait(15000, function()
    while seen < #recorder.events do
      seen = seen + 1
      local event = recorder.events[seen]
      if event.method == "cmp_load_input_done" then
        input_done = event.args[1]
      elseif event.method == "cmp_load_request" then
        pending_requests[event.args[1]] = true
      elseif event.method == "cmp_load_response" then
        pending_requests[event.args[1]] = nil
        last_response = event.time
      end
    end
    return input_done ~= nil
      and next_key > #plan
      and next(pending_requests) == nil
      and vim.uv.hrtime() > last_response + 20e6
      and vim.uv.hrtime() > math.max(input_done, sent[#plan].sent_ns) + scenario.settle_ms * 1e6
  end, 1)
  timer:stop()
  timer:close()
  assert(ok, "open-loop input timeout: sent=" .. #sent .. ", pending=" .. vim.inspect(pending_requests))
  local trace = ui:lua("return require('__test__.bench.cmp.load_editor').finish()")
  trace.sent = sent
  trace.flushes = {}
  local pending_line, pending_menu
  local current_sequence = 0
  local current_query = scenario.seed or ""
  for _, event in ipairs(recorder.events) do
    if event.method == "cmp_load_line" then
      pending_line = event.args[1]
      current_sequence = pending_line.sequence
      current_query = pending_line.line
    elseif event.method == "cmp_load_menu" then
      pending_menu = event.args[1]
    elseif event.method == "redraw" then
      for _, update in ipairs(event.args) do
        if update[1] == "flush" and (pending_line or pending_menu) then
          -- Several redraws may be coalesced; only the final state reaches this flush.
          trace.flushes[#trace.flushes + 1] = {
            time_ns = event.time,
            current_sequence = current_sequence,
            current_query = current_query,
            line_sequence = pending_line and pending_line.sequence,
            menu_sequence = pending_menu and pending_menu.sequence,
            menu_query = pending_menu and pending_menu.query,
            menu_visible = pending_menu ~= nil and pending_menu.visible and pending_menu.count > 0,
          }
          pending_line, pending_menu = nil, nil
        end
      end
    end
  end
  assert(#trace.keys == #plan and #trace.unexpected_keys == 0, "input trace mismatch: " .. vim.inspect(trace.keys))
  assert(trace.final_line == plan[#plan].query, "input text was lost or reordered")
  assert(trace.errmsg == "", trace.errmsg)
  return trace
end

---@param options                       table
---@return table
function M.run(options)
  local result = {
    cases = {},
    heartbeat_period_ms = 2,
    note = "parent schedules asynchronous nvim_input at fixed deadlines; same-host monotonic clocks; CPU is whole child process; 2ms heartbeat includes OS scheduling; full GC is outside timed burst; server payloads prepared beforehand; cancelled requests still deliver replies",
  }
  local scenarios = {
    { name = "input_control_10ms", count = 0, interval_ms = 10, seed = "g", control = true },
    { name = "warm_10000_50ms", count = 10000, interval_ms = 50, seed = "g" },
    { name = "warm_50000_50ms", count = 50000, interval_ms = 50, seed = "g" },
    { name = "warm_50000_10ms", count = 50000, interval_ms = 10, seed = "g" },
    { name = "dense_50000_20ms", count = 50000, interval_ms = 20, seed = "complei", dense = true },
    { name = "fresh_50000_10ms", count = 50000, interval_ms = 10 },
    {
      name = "incomplete_1000_10ms",
      count = 1000,
      interval_ms = 10,
      seed = "g",
      incomplete = true,
      response_delays = { 80, 5, 60, 5 },
    },
    {
      name = "hide_1000_10ms",
      count = 1000,
      interval_ms = 10,
      incomplete = true,
      response_delays = { 120 },
      hide = true,
    },
  }
  for _, scenario in ipairs(scenarios) do
    if options.case_filter == nil or scenario.name:find(options.case_filter, 1, true) then
      scenario.settle_ms = scenario.incomplete and 180 or 60
      local plan = input_plan(scenario)
      local engine = scenario.control and "none" or "era"
      io.stdout:write("  " .. scenario.name .. " / " .. engine .. "\n")
      io.stdout:flush()
      local ui, recorder = Child.start()
      local sample_index
      local ok, err = xpcall(function()
        ui:lua(
          "require('__test__.bench.cmp.load_editor').setup(...)",
          vim.tbl_extend("force", options, scenario, { engine = engine })
        )
        local samples = {}
        for sample = 1, options.iterations + 5 do
          sample_index = sample
          local trace = burst(ui, recorder, scenario, plan)
          if sample > 5 then
            samples[#samples + 1] = trace
          end
        end
        result.cases[#result.cases + 1] = { scenario = scenario, engine = engine, plan = plan, iterations = samples }
        vim.fn.writefile({ vim.json.encode(result) }, options.output .. "/load.partial.json")
      end, debug.traceback)
      if not ok then
        local mode_ok, mode = pcall(ui.rpc, ui, "nvim_get_mode")
        local failure = {
          scenario = scenario.name,
          engine = engine,
          sample = sample_index,
          error = err,
          mode = mode_ok and mode or nil,
          stderr = ui.stderr,
          notifications = vim.list_slice(recorder.events, math.max(1, #recorder.events - 99)),
        }
        vim.fn.writefile(vim.split(vim.inspect(failure), "\n", { plain = true }), options.output .. "/load-failure.txt")
      end
      ui:close()
      assert(ok, err)
    end
  end
  assert(#result.cases > 0, "no load scenarios matched filter: " .. tostring(options.case_filter))
  vim.fn.delete(options.output .. "/load.partial.json")
  return result
end

return M
