-- Usage, from the repository root: nvim -l __test__/bench/treeview.lua [tree|ancestry] [processes=1]
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.treeview" ---@type string

local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.api.nvim_set_current_dir(root)
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local Record = require("__test__.bench.record")
local Stats = require("__test__.bench.stats")
local mode = arg[1] or "tree" ---@type string
local processes = tonumber(arg[2]) or 1
assert(
  (mode == "tree" or mode == "ancestry") and processes >= 1 and processes % 1 == 0,
  "usage: nvim -l __test__/bench/treeview.lua [tree|ancestry] [processes]"
)
local ITERATIONS = 100
local KINDS = { "text", "text_filtered", "selection", "filter" }

---Appends the milliseconds from `from` to `to` to `metrics[name]` when the sample reached both points.
---@param metrics                       table<string, number[]>
---@param name                          string
---@param from                          integer|nil
---@param to                            integer|nil
---@return nil
local function record(metrics, name, from, to)
  if from and to then
    local values = metrics[name] or {}
    values[#values + 1] = (to - from) / 1000000
    metrics[name] = values
  end
end

---Measures every path in a fresh child Neovim and returns each path's per-sample metrics.
---@param ui                            table
---@return table<string, table<string, number[]>> samples
---@return table memory
local function measure(ui)
  ui:rpc("nvim_ui_attach", 80, 48, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local root, mode = ...
    vim.opt.runtimepath:prepend(root)
    yoz = assert(package.loadlib(root .. "/lua/yoz.so", "luaopen_yoz"))()
    bench_errors = {}
    stl = { c = { Future = require("stl.c.future") }, nvim = { fn = require("stl.nvim.fn") },
      reporter = { error = function(options) bench_errors[#bench_errors + 1] = options.message end } }
    local function await(future)
      assert(vim.wait(10000, function() return future:is_done() end))
      assert(not future:is_failed(), future:get_error())
      return future:get_result()
    end
    local treeview = require("ux.treeview")
    local surface, async = require("ux.treeview.surface"), require("ux.treeview.async")
    local request, run, requesting = surface.request, async.run, false
    surface.request = function(...)
      if bench_pending then bench_pending.projected = vim.uv.hrtime() end
      requesting = true
      request(...)
      requesting = false
    end
    async.run = function(ticket)
      local future = run(ticket)
      if requesting then future:finally(function(ok)
        if ok and bench_pending then bench_pending.planned = vim.uv.hrtime() end
      end) end
      return future
    end
    local set_lines = vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines = function(...)
      if bench_pending then bench_pending.writing = bench_pending.writing or vim.uv.hrtime() end
      return set_lines(...)
    end
    bench_data = treeview.new_data()
    local records = { { key = "root", label = "root", can_expand = true } }
    for i = 0, 49999 do records[#records + 1] = {
      key = "n" .. i, parent = "root", label = string.format("node-%05d", i) .. string.rep("x", 86),
      highlight = "Normal", right_text = "detail",
    } end
    assert(await(bench_data:import(records)).kind == "Applied")
    local id = bench_data:source():id("root")
    bench_display = { pattern = "", mode = mode == "ancestry" and "list" or "tree", list_text = mode == "ancestry" and "ancestry" or "label" }
    bench_state = await(bench_data:create_state(mode == "ancestry" and { kind = "forest", nodes = { id } } or { kind = "children_of", node = id }, bench_display))
    bench_view = treeview.attach(bench_state, { keymaps = false })
    assert(vim.wait(10000, function() return bench_view:frame() ~= nil end))
    function bench_set_pattern(pattern)
      bench_display = vim.tbl_extend("force", bench_display, { pattern = pattern })
      local result = await(bench_state:set_display(bench_display))
      assert(result.kind == "Applied", vim.inspect(result))
      assert(vim.wait(10000, function()
        local frame = bench_view:frame()
        return frame ~= nil and bench_state:native():applicable(frame, result.revisions.commit)
      end))
    end
    local redraw = vim.api.nvim__redraw
    vim.api.nvim__redraw = function(options)
      if bench_view and bench_view:frame() and bench_pending then
        local frame = bench_view:frame()
        if frame:id() ~= bench_pending.base then
          bench_pending.publication = { frame = frame, at = vim.uv.hrtime() }
        end
      end
      return redraw(options)
    end
    collectgarbage("collect")
  ]],
    { root, mode }
  )
  local samples = {}
  for _, kind in ipairs(KINDS) do
    if kind == "text_filtered" then
      ui:rpc("nvim_exec_lua", 'bench_set_pattern("node-")', {})
    end
    for index = 1, ITERATIONS do
      -- Filter inputs alternate between narrowing to 100 matches and widening back to all 50,000 rows.
      local path = kind == "filter" and (index % 2 == 1 and "filter_narrow" or "filter_widen") or kind
      samples[path] = samples[path] or {}
      if kind == "text" or kind == "text_filtered" then
        -- Let the 8 ms pacing of data-only publications lapse, so each update is measured on its own.
        vim.uv.sleep(10)
      end
      ui:rpc(
        "nvim_exec_lua",
        [[
        local kind, index = ...
        bench_pending = { base = bench_view:frame():id(), started = vim.uv.hrtime() }
        local future
        if kind == "text" or kind == "text_filtered" then
          future = bench_data:batch({ { kind = "update", node = "n20", label = string.format("node-%05d", index) .. string.rep("y", 86) } })
        elseif kind == "selection" then
          future = bench_state:toggle_node({ bench_data:source():id("n20") }, false, bench_view:frame())
        else
          future = bench_state:set_display(vim.tbl_extend("force", bench_display, { pattern = index % 2 == 1 and "node-000" or "node-" }))
        end
        future:finally(function(ok, result)
          if not ok or result.kind ~= "Applied" then bench_errors[#bench_errors + 1] = vim.inspect(result); return end
          bench_pending.expected = result.revisions.commit
        end)
      ]],
        { kind, index }
      )
      local times
      ui:wait_until(function()
        times = ui:rpc(
          "nvim_exec_lua",
          [[
          if #bench_errors > 0 then error(table.concat(bench_errors, "\n")) end
          local pending = bench_pending
          if pending.expected and pending.publication and bench_state:native():applicable(pending.publication.frame, pending.expected) then
            return { pending.started, pending.publication.at, pending.projected, pending.planned, pending.writing }
          end
        ]],
          {}
        )
        return times and ui.last_flush and ui.last_flush >= times[2]
      end, 10000, "frame did not flush", 1)
      local metrics, flushed = samples[path], ui.last_flush
      record(metrics, "publication", times[1], times[2])
      record(metrics, "flush", times[1], flushed)
      -- Lua publication starts by requesting the RenderPlan; Selection publishes without writing body text.
      record(metrics, "lua_publish", times[3], flushed)
      record(metrics, "projection_observed", times[1], times[3])
      record(metrics, "plan_handoff", times[3], times[4])
      record(metrics, "staging", times[4], times[5])
      record(metrics, "publish_flush", times[5], flushed)
    end
  end
  local memory = {
    lua_heap_bytes = ui:rpc("nvim_exec_lua", 'collectgarbage("collect"); return collectgarbage("count") * 1024', {}),
    process_memory_bytes = ui:rpc("nvim_exec_lua", "return vim.uv.resident_set_memory()", {}),
  }
  return samples, memory
end

local result = {
  rows = 50000,
  label_bytes = 96,
  ancestry_prefix_bytes = mode == "ancestry" and 5 or 0,
  mode = mode,
  ui = { 80, 48 },
  units = "milliseconds",
  paths = {},
  per_process = {},
}
local pooled = {}
for _ = 1, processes do
  local ui = require("__test__.support.ui").new()
  local ok, samples, memory = xpcall(measure, debug.traceback, ui)
  ui:close()
  if not ok then
    error(samples)
  end
  local process = vim.tbl_extend("error", memory, { flush_p95 = {} })
  for path, metrics in pairs(samples) do
    process.flush_p95[path] = Stats.percentile(metrics.flush, 0.95)
    pooled[path] = pooled[path] or {}
    for name, values in pairs(metrics) do
      pooled[path][name] = vim.list_extend(pooled[path][name] or {}, values)
    end
  end
  result.per_process[#result.per_process + 1] = process
end
for path, metrics in pairs(pooled) do
  result.paths[path] = {}
  for name, values in pairs(metrics) do
    result.paths[path][name] = Stats.summary(values)
  end
end
io.stdout:write(vim.json.encode(result), "\n")
io.stdout:write(
  "results: ",
  Record.write("treeview", {
    conditions = { mode = mode, ui = { 80, 48 }, processes = processes, iterations = ITERATIONS },
    results = result,
  }),
  "\n"
)
