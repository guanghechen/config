---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.treeview" ---@type string

local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.api.nvim_set_current_dir(root)
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local ui = require("__test__.support.ui").new()
local mode = arg[1] or "tree" ---@type string
assert(mode == "tree" or mode == "ancestry", "usage: nvim -l __test__/bench/treeview.lua [tree|ancestry]")

---@param values                        number[]
---@return table
local function distribution(values)
  table.sort(values)
  return {
    samples = #values,
    p50 = values[math.ceil(#values * 0.5)],
    p95 = values[math.ceil(#values * 0.95)],
    max = values[#values],
  }
end

local ok, result = xpcall(function()
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
    bench_display = { pattern = "node-", mode = mode == "ancestry" and "list" or "tree", list_text = mode == "ancestry" and "ancestry" or "label" }
    bench_state = await(bench_data:create_state(mode == "ancestry" and { kind = "forest", nodes = { id } } or { kind = "children_of", node = id }, bench_display))
    bench_view = treeview.attach(bench_state, { keymaps = false })
    assert(vim.wait(10000, function() return bench_view:frame() ~= nil end))
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
  local output = {
    rows = 50000,
    label_bytes = 96,
    ancestry_prefix_bytes = mode == "ancestry" and 5 or 0,
    mode = mode,
    ui = { 80, 48 },
    units = "milliseconds",
    paths = {},
  }
  for _, kind in ipairs({ "text", "selection", "filter" }) do
    local publication, flush = {}, {}
    local stages = { projection_observed = {}, plan_handoff = {}, staging = {}, publish_flush = {} }
    for index = 1, 100 do
      ui:rpc(
        "nvim_exec_lua",
        [[
        local kind, index = ...
        bench_pending = { base = bench_view:frame():id(), started = vim.uv.hrtime() }
        local future
        if kind == "text" then
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
      assert(
        vim.wait(10000, function()
          times = ui:rpc(
            "nvim_exec_lua",
            [[
          if #bench_errors > 0 then error(table.concat(bench_errors, "\n")) end
          local pending = bench_pending
          if pending.expected and pending.publication and bench_state._native:applicable(pending.publication.frame, pending.expected) then
            return { pending.started, pending.publication.at, pending.projected, pending.planned, pending.writing }
          end
        ]],
            {}
          )
          return times and ui.last_flush and ui.last_flush >= times[2]
        end, 1),
        "frame did not flush"
      )
      publication[#publication + 1] = (times[2] - times[1]) / 1000000
      flush[#flush + 1] = (ui.last_flush - times[1]) / 1000000
      if times[5] and times[4] and times[3] then
        stages.projection_observed[#stages.projection_observed + 1] = (times[3] - times[1]) / 1000000
        stages.plan_handoff[#stages.plan_handoff + 1] = (times[4] - times[3]) / 1000000
        stages.staging[#stages.staging + 1] = (times[5] - times[4]) / 1000000
        stages.publish_flush[#stages.publish_flush + 1] = (ui.last_flush - times[5]) / 1000000
      end
    end
    output.paths[kind] = { publication = distribution(publication), flush = distribution(flush) }
    for name, samples in pairs(stages) do
      if #samples > 0 then
        output.paths[kind][name] = distribution(samples)
      end
    end
  end
  output.lua_heap_kib = ui:rpc("nvim_exec_lua", 'collectgarbage("collect"); return collectgarbage("count")', {})
  local pid = ui:rpc("nvim_exec_lua", "return vim.uv.os_getpid()", {})
  output.rss_kib = tonumber(vim.system({ "ps", "-o", "rss=", "-p", tostring(pid) }, { text = true }):wait().stdout)
  output.nvim = vim.version()
  output.system = vim.uv.os_uname()
  return output
end, debug.traceback)
ui:close()
if not ok then
  error(result)
end
io.stdout:write(vim.json.encode(result), "\n")
