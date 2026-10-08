---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.treeview_consumers"
local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.api.nvim_set_current_dir(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local mode, samples = arg[1] or "searcher", tonumber(arg[2]) or 100
assert(vim.tbl_contains({ "filetree", "searcher", "git", "lsp" }, mode), "expected filetree, searcher, git, or lsp")
local ui = require("__test__.support.ui").new()
local ok, result = xpcall(function()
  ui:rpc("nvim_ui_attach", 80, 48, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local root, mode = ...
    consumer_bench = assert(loadfile(root .. "/__test__/fixtures/ux/treeview/consumers.lua"))()
    consumer_bench.setup(root, mode)
  ]],
    { root, mode }
  )
  local rows = {}
  for iteration = 1, samples + 5 do
    ui:rpc("nvim_exec_lua", "consumer_bench.start(...)", { iteration })
    local times, first_flush
    assert(
      vim.wait(30000, function()
        times = ui:rpc("nvim_exec_lua", "return consumer_bench.poll()", {})
        if times.first and ui.last_flush and ui.last_flush >= times.first then
          first_flush = first_flush or ui.last_flush
        end
        return times.published and ui.last_flush and ui.last_flush >= times.published
      end, 1),
      "consumer frame did not flush"
    )
    if iteration > 5 then
      rows[#rows + 1] = {
        first_flush_ms = (first_flush - times.started) / 1e6,
        final_flush_ms = (ui.last_flush - times.started) / 1e6,
        producer_ms = (times.io_ready - times.started) / 1e6,
        producer_to_flush_ms = (ui.last_flush - times.io_ready) / 1e6,
        watch_or_schedule_ms = (times.io_started - times.started) / 1e6,
        io_ms = (times.io_ready - times.io_started) / 1e6,
        extraction_ms = times.extract_ns / 1e6,
        native_poll_ms = times.native_poll_ns / 1e6,
        publication_ms = (times.published - times.started) / 1e6,
        final_plan_requested_ms = (times.plan_requested - times.started) / 1e6,
        final_plan_ready_ms = (times.plan_ready - times.started) / 1e6,
        final_staging_done_ms = times.staging_done and (times.staging_done - times.started) / 1e6 or nil,
        buffer_ms = times.buffer_ns / 1e6,
        nodes = times.nodes,
        pages = times.pages,
        raw_heap_kib = times.raw_heap_kib,
        stage_heap_kib = times.stage_heap_kib,
        buffer_bytes = times.buffer_bytes,
      }
    end
  end
  local retained = ui:rpc("nvim_exec_lua", 'collectgarbage("collect"); return collectgarbage("count")', {})
  local pid = ui:rpc("nvim_exec_lua", "return vim.uv.os_getpid()", {})
  local rss = tonumber(vim.system({ "ps", "-o", "rss=", "-p", tostring(pid) }, { text = true }):wait().stdout)
  local closed = ui:rpc("nvim_exec_lua", "return consumer_bench.finish()", {})
  local collected = ui:rpc("nvim_exec_lua", "return consumer_bench.collect()", {})
  closed.lua_heap_kib = collected.lua_heap_kib
  closed.gc_ms = collected.gc_ms
  closed.release_ms = closed.release_ms + collected.gc_ms
  closed.handles_released = true
  return {
    mode = mode,
    samples = rows,
    lua_retained_kib = retained,
    rss_kib = rss,
    closed = closed,
    nvim = vim.version(),
  }
end, debug.traceback)
local _, directory = pcall(ui.rpc, ui, "nvim_exec_lua", "return consumer_bench and consumer_bench.directory", {})
ui:close()
if type(directory) == "string" then
  vim.fn.delete(directory, "rf")
end
if not ok then
  error(result)
end
io.stdout:write(vim.json.encode(result), "\n")
