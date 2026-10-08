---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.filetree" ---@type string

local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.api.nvim_set_current_dir(root)
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local samples = tonumber(arg[1]) or 10
local mode = arg[2] or "tree"
local annotations = arg[3] == "annotations"
assert(samples >= 1 and samples <= 100 and (mode == "tree" or mode == "list"))
local directory = vim.fn.tempname()
assert(vim.uv.fs_mkdir(directory, 448))
local prepared = vim
  .system({
    "python3",
    "-c",
    [[import pathlib,sys
p=pathlib.Path(sys.argv[1])
for i in range(50000): (p / f"file-{i:05}").touch()
]],
    directory,
  }, { text = true })
  :wait()
assert(prepared.code == 0, prepared.stderr)
local ui = require("__test__.support.ui").new()

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
    local root = ...
    vim.opt.runtimepath:prepend(root)
    yoz = assert(package.loadlib(root .. "/lua/yoz.so", "luaopen_yoz"))()
    bench_errors = {}
    stl = { c = { Future = require("stl.c.future") }, nvim = { fn = require("stl.nvim.fn") },
      reporter = { error = function(options) bench_errors[#bench_errors + 1] = options.message end } }
    local redraw = vim.api.nvim__redraw
    vim.api.nvim__redraw = function(options)
      if bench_annotation and bench_view._filetree_annotations
        and bench_view._filetree_annotations.rows[1].diagnostics[2] == bench_annotation.count then
        bench_annotation.published = bench_annotation.published or vim.uv.hrtime()
      end
      if bench_view and bench_view:frame() and bench_pending then
        local frame = bench_view:frame()
        if frame:header().row_count >= 512 then bench_pending.first = bench_pending.first or vim.uv.hrtime() end
        local node = frame:source():node(bench_data.root)
        if frame:header().row_count == 50000 and node.completeness == "complete" and bench_state._native:applicable(frame) then
          bench_pending.complete = bench_pending.complete or vim.uv.hrtime()
        end
      end
      return redraw(options)
    end
    collectgarbage("collect")
  ]],
    { root }
  )
  local first, complete, first_flush, complete_flush = {}, {}, {}, {}
  for index = 1, samples do
    ui:rpc(
      "nvim_exec_lua",
      [[
      local path, mode = ...
      if bench_view then bench_view:detach() end
      bench_view, bench_state, bench_data = nil, nil, nil
      local function await(future)
        assert(vim.wait(10000, function() return future:is_done() end, 1))
        assert(not future:is_failed(), future:get_error())
        local value = future:get_result()
        assert(not (type(value) == "table" and value.kind == "Rejected"), vim.inspect(value))
        return value
      end
      local filetree = require("ux.filetree")
      bench_pending = { started = vim.uv.hrtime() }
      bench_data = await(filetree.open(path))
      bench_state = await(bench_data:create_state(nil, { mode = mode }))
      bench_view = filetree.attach(bench_state, { keymaps = false })
    ]],
      { directory, mode }
    )
    local first_at, done
    assert(
      vim.wait(30000, function()
        local times = ui:rpc(
          "nvim_exec_lua",
          [[
        if #bench_errors > 0 then error(table.concat(bench_errors, "\n")) end
        return { bench_pending.started, bench_pending.first or false, bench_pending.complete or false }
      ]],
          {}
        )
        if times[2] and not first_at and ui.last_flush and ui.last_flush >= times[2] then
          first_at = true
          first[#first + 1] = (times[2] - times[1]) / 1000000
          first_flush[#first_flush + 1] = (ui.last_flush - times[1]) / 1000000
        end
        if times[3] and ui.last_flush and ui.last_flush >= times[3] then
          complete[#complete + 1] = (times[3] - times[1]) / 1000000
          complete_flush[#complete_flush + 1] = (ui.last_flush - times[1]) / 1000000
          done = true
        end
        return done
      end, 1),
      "Filetree did not finish and flush"
    )
  end
  local annotation_metrics
  if annotations then
    local viewport, navigation, updates = {}, {}, {}
    ui:rpc(
      "nvim_exec_lua",
      [[
      local path = ...
      vim.api.nvim_win_set_cursor(bench_view.winnr, {1, 0})
      local pending = bench_data:set_diagnostics(1, 2, 1, path .. "/file-49999", {1, 0, 0, 0})
      assert(vim.wait(10000, function() return pending:is_done() end, 1))
      assert(pending:get_result() == true)
    ]],
      { directory }
    )
    for index = 1, samples do
      local times = ui:rpc(
        "nvim_exec_lua",
        [[
        local function await(future)
          assert(vim.wait(10000, function() return future:is_done() end, 1))
          local value = future:get_result()
          assert(not (type(value) == "table" and value.kind == "Rejected"), vim.inspect(value))
          return value
        end
        local start = vim.uv.hrtime()
        local rows = await(bench_data:annotations(bench_view:frame(), 1, 48))
        assert(#rows.rows == 48)
        local viewport = (vim.uv.hrtime() - start) / 1000000
        start = vim.uv.hrtime()
        assert(await(bench_data:next_annotation(bench_view:frame(), 0, "error", true)) == 50000)
        return { viewport, (vim.uv.hrtime() - start) / 1000000 }
      ]],
        {}
      )
      viewport[#viewport + 1], navigation[#navigation + 1] = times[1], times[2]
      ui:rpc(
        "nvim_exec_lua",
        [[
        local path, count = ...
        bench_annotation = { started = vim.uv.hrtime(), count = count }
        bench_data:set_diagnostics(1, 1, count, path .. "/file-00000", {0, count, 0, 0})
      ]],
        { directory, index }
      )
      local deadline = vim.uv.hrtime() + 10000000000
      assert(
        vim.wait(10000, function()
          assert(vim.uv.hrtime() < deadline, "Filetree annotations did not flush")
          local times = ui:rpc(
            "nvim_exec_lua",
            [[
          if #bench_errors > 0 then error(table.concat(bench_errors, "\n")) end
          return { bench_annotation.started, bench_annotation.published or false }
        ]],
            {}
          )
          if times[2] and ui.last_flush and ui.last_flush >= times[2] then
            updates[#updates + 1] = (ui.last_flush - times[1]) / 1000000
            return true
          end
        end, 1),
        "Filetree annotations did not flush"
      )
    end
    annotation_metrics = {
      viewport48 = distribution(viewport),
      navigation50000 = distribution(navigation),
      update_flush = distribution(updates),
    }
  end
  local output = {
    entries = 50000,
    mode = mode,
    ui = { 80, 48 },
    units = "milliseconds",
    gc = "natural during samples",
    first512_publication = distribution(first),
    first512_flush = distribution(first_flush),
    complete_publication = distribution(complete),
    complete_flush = distribution(complete_flush),
    annotations = annotation_metrics,
    memory = ui:rpc(
      "nvim_exec_lua",
      [[
      collectgarbage("collect")
      return { rust = bench_data._native:stats(), lua_heap_kib = collectgarbage("count"), buffer_lines = vim.api.nvim_buf_line_count(bench_view.bufnr) }
    ]],
      {}
    ),
    nvim = vim.version(),
    system = vim.uv.os_uname(),
  }
  local pid = ui:rpc("nvim_exec_lua", "return vim.uv.os_getpid()", {})
  output.memory.rss_kib =
    tonumber(vim.system({ "ps", "-o", "rss=", "-p", tostring(pid) }, { text = true }):wait().stdout)
  return output
end, debug.traceback)
ui:close()
vim.fn.delete(directory, "rf")
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
