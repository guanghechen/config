-- Usage, from the repository root: nvim -l __test__/bench/treeview_results.lua [count=50000]
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.treeview_results" ---@type string
local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.api.nvim_set_current_dir(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local count = tonumber(arg[1]) or 50000
local Record = require("__test__.bench.record")
local Stats = require("__test__.bench.stats")
local ui = require("__test__.support.ui").new({ timeout_ms = 60000 })
local ok, result = xpcall(function()
  ui:rpc("nvim_ui_attach", 100, 40, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local root, count = ...
    vim.opt.runtimepath:prepend(root)
    package.cpath = root .. "/lua/?.so;" .. package.cpath
    require("ark.bootstrap").setup()
    bench = { errors = {}, writes = 0 }
    stl.reporter.error = function(value) bench.errors[#bench.errors + 1] = value.message end
    collectgarbage("collect")
    bench.base_heap = collectgarbage("count")
    local paths = {}
    for index = 1, count do
      paths[index] = string.format("dir%04d/file%06d.lua", math.floor((index - 1) / 100), index)
    end
    local Source = require("era.view.result_paths")
    local Files = require("era.view.result_files")
    bench.owner = Files.new({ name = "result benchmark", tree = Source.new() })
    bench.started = vim.uv.hrtime()
    bench.owner:reset_filepaths("/virtual-results", paths, false)
    bench.produced = vim.uv.hrtime()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, bufnr)
    bench.owner:mount(vim.api.nvim_get_current_win(), bufnr, function(frame)
      bench.published = vim.uv.hrtime()
      bench.row = frame:header().cursor_row
    end)
    bench.owner:publish({ mode = "tree", rootuuid = Source.key("/virtual-results"), foldempty = true })
    local set_lines = vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines = function(...)
      bench.writes = bench.writes + 1
      return set_lines(...)
    end
  ]],
    { root, count }
  )
  local ready
  local deadline = vim.uv.hrtime() + 60000000000
  ui:wait_until(function()
    if vim.uv.hrtime() >= deadline then
      error(
        "initial publication stalled: "
          .. vim.inspect(
            ui:rpc(
              "nvim_exec_lua",
              "return {errors=bench.errors, busy=bench.owner._busy, ready=bench.owner:is_current()}",
              {}
            )
          )
      )
    end
    ready = ui:rpc(
      "nvim_exec_lua",
      [[
      if not bench.owner:is_current() or not bench.published then return false end
      return { started = bench.started, produced = bench.produced, published = bench.published, rows = bench.owner:linecount() }
    ]],
      {}
    )
    return ready and ui.last_flush and ui.last_flush >= ready.published
  end, 60000, "initial result did not flush", 1)
  local initial = ui.last_flush
  ui:rpc("nvim_exec_lua", "bench.writes = 0", {})
  local samples, confirmations = {}, {}
  for iteration = 1, 30 do
    local row = iteration + 1
    local started = ui:rpc(
      "nvim_exec_lua",
      [[
      local row = ...
      local started = vim.uv.hrtime()
      bench.cursor_future = bench.owner.view:set_cursor(row)
      return started
    ]],
      { row }
    )
    local published, first_flush
    deadline = vim.uv.hrtime() + 10000000000
    ui:wait_until(function()
      if vim.uv.hrtime() >= deadline then
        error("cursor publication stalled: " .. vim.inspect(ui:rpc(
          "nvim_exec_lua",
          [[
          local status = bench.owner.view:status()
          local latest = bench.owner.state:snapshot():header()
          return { row = bench.row, published = bench.published, errors = bench.errors,
            state_row = latest.cursor_row, frame_row = status.frame and status.frame.cursor_row,
            preparing = status.preparing, error = status.error, future = bench.cursor_future:get_result() and bench.cursor_future:get_result().kind,
            cursor = vim.api.nvim_win_get_cursor(bench.owner.view.winnr), mode = vim.api.nvim_get_mode().mode }
        ]],
          {}
        )))
      end
      published = ui:rpc("nvim_exec_lua", "return bench.row == ... and bench.published or false", { row })
      if ui.last_flush and ui.last_flush >= started then
        first_flush = first_flush or ui.last_flush
      end
      return published and first_flush ~= nil
    end, 10000, "cursor frame did not flush", 1)
    samples[#samples + 1] = (first_flush - started) / 1e6
    confirmations[#confirmations + 1] = (published - started) / 1e6
  end
  local counters = ui:rpc(
    "nvim_exec_lua",
    [[
    collectgarbage("collect")
    return { writes = bench.writes, heap_bytes = (collectgarbage("count") - bench.base_heap) * 1024, errors = bench.errors }
  ]],
    {}
  )
  assert(#counters.errors == 0, vim.inspect(counters.errors))
  ui:rpc(
    "nvim_exec_lua",
    [[
    local frame = bench.owner:frame()
    local key = frame:node_keys({frame:node_at(1)})[1]
    bench.owner:toggle_select(key, true, true)
    bench.selection_ready = bench.owner:ready()
  ]],
    {}
  )
  ui:wait_until(function()
    return ui:rpc("nvim_exec_lua", "return bench.selection_ready:is_done()", {})
  end, 10000, "selection did not publish", 1)
  local selection = ui:rpc(
    "nvim_exec_lua",
    [[
    assert(not bench.selection_ready:is_failed(), bench.selection_ready:get_error())
    local started = vim.uv.hrtime()
    local keys = bench.owner:selected_keys(true)
    return {count=#keys, ms=(vim.uv.hrtime()-started)/1e6}
  ]],
    {}
  )
  return {
    files = count,
    rows = ready.rows,
    producer_ms = (ready.produced - ready.started) / 1e6,
    initial_flush_ms = (initial - ready.started) / 1e6,
    cursor_flush_ms = Stats.summary(samples),
    cursor_confirmation_ms = Stats.summary(confirmations),
    cursor_buffer_writes = counters.writes,
    lua_retained_bytes = counters.heap_bytes,
    selected_nodes = selection.count,
    selected_keys_ms = selection.ms,
  }
end, debug.traceback)
ui:close()
if not ok then
  error(result)
end
io.stdout:write(vim.json.encode(result), "\n")
local conditions = { files = count, cursor_iterations = 30, ui = { 100, 40 } }
io.stdout:write("results: ", Record.write("treeview_results", { conditions = conditions, results = result }), "\n")
