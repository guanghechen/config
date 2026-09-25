---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.soak" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
package.path = root .. "/?.lua;" .. package.path
local cycles, entries = tonumber(arg[1]) or 100, tonumber(arg[2]) or 1000
assert(cycles >= 20 and cycles % 20 == 0 and cycles <= 10000, "cycles must be a multiple of 20, from 20 through 10000")
assert(entries >= 100 and entries <= 50000 and entries % 1 == 0, "file count must be from 100 through 50000")
local branch = math.floor(entries / 10)
local top = entries - branch
local directory = vim.fn.tempname()
assert(vim.uv.fs_mkdir(directory, 448))
local ui

---@param path                          string
---@return nil
local function empty_file(path)
  local fd = assert(vim.uv.fs_open(path, "wx", 384))
  assert(vim.uv.fs_close(fd))
end

local ok, result = xpcall(function()
  assert(vim.uv.fs_mkdir(directory .. "/a-branch", 448))
  for index = 1, top do
    empty_file(string.format("%s/file-%05d.lua", directory, index))
  end
  for index = 1, branch do
    empty_file(string.format("%s/a-branch/inside-%05d.lua", directory, index))
  end
  empty_file(directory .. "/a-watch.lua")
  ui = require("__test__.support.ui").new({ timeout_ms = 30000 })
  local watched
  local grid = require("__test__.support.ui_grid").new(ui, function(screen)
    if watched and not watched.flushed and screen:find(watched.name) then
      watched.flushed = vim.uv.hrtime()
    end
  end)
  ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local file, root, directory, top, branch = ...
    assert(loadfile(file))(root, directory, "native", top + 1, branch, "tree")
  ]],
    { here .. "/runtime.lua", root, directory, top, branch }
  )
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local rows, nested = ...
    soak = { rows = rows, nested = nested, buffers = {}, released_refs = {}, releases = {} }
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do soak.buffers[bufnr] = true end

    ---@param future                    stl.c.Future
    ---@return any
    function soak.await(future)
      assert(vim.wait(10000, function() return future:is_done() end, 1), "Future timed out")
      assert(not future:is_failed(), future:get_error())
      local value = future:get_result()
      assert(type(value) ~= "table" or value.kind ~= "Rejected", vim.inspect(value))
      return value
    end

    ---@param expected                  integer
    ---@return nil
    function soak.settled(expected)
      assert(vim.wait(10000, function()
        if not bench.widget then return false end
        local session = bench.widget._session
        local view = bench.widget._views[vim.api.nvim_get_current_tabpage()]
        return session and view and view:frame() and view:frame():header().row_count == expected
          and not view._busy and not view._filetree_pending and not session._subscriptions._running
          and not session.data._native:is_busy() and view:frame():header().data_revision == session.data:source():revision()
      end, 1), "Explorer did not settle at " .. expected .. " rows")
      assert(#bench.errors == 0, vim.inspect(bench.errors))
    end

    ---@return nil
    function soak.open()
      bench.start("open", soak.rows)
      soak.settled(soak.rows)
    end

    ---@param index                     integer
    ---@return nil
    function soak.prepare(index)
      local widget = bench.widget
      local session, view = widget:context()
      vim.api.nvim_win_set_cursor(view.winnr, { 1, 0 })
      widget._action:activate()
      soak.settled(soak.rows + soak.nested)
      widget._action:activate()
      soak.settled(soak.rows)
      widget:toggle_flag(2)
      soak.settled(soak.rows + soak.nested)
      assert(view:frame():header().mode == "list")
      widget:toggle_flag(2)
      soak.settled(soak.rows)
      assert(view:frame():header().mode == "tree")
      soak.await(widget:refresh())
      soak.settled(soak.rows)
      if index % 10 == 0 then
        local original = vim.api.nvim_get_current_tabpage()
        vim.cmd.tabnew()
        local scratch = vim.api.nvim_get_current_buf()
        vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = scratch })
        widget:focus()
        soak.settled(soak.rows)
        local second = vim.api.nvim_get_current_tabpage()
        vim.api.nvim_set_current_tabpage(original)
        widget:hide(second)
        vim.api.nvim_set_current_tabpage(second)
        vim.cmd.tabclose()
        vim.api.nvim_set_current_tabpage(original)
      end
      bench.reset_cursor()
      assert(vim.wait(10000, function() return session.data:watch_status().directories > 0 end, 1))
    end

    ---@param index                     integer
    ---@return table
    function soak.finish(index)
      local widget = bench.widget
      local session, view = widget:context()
      local weak = setmetatable({ widget, session, session.data, view }, { __mode = "v" })
      widget:hide()
      assert(vim.wait(10000, function()
        return session.data:watch_status().directories == 0 and not session.data._native:is_busy()
          and session.data._native:stats().queue_depth == 0
      end, 1), "hidden pane retained watches or queued work")
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        assert(soak.buffers[bufnr], "orphan buffer: " .. vim.api.nvim_buf_get_name(bufnr))
      end
      local memory = bench.memory()
      memory.cycle, memory.hidden_watches = index, session.data:watch_status().directories
      if index % 20 == 0 then
        widget:dispose()
        bench.widget, bench.phase, widget, session, view = nil, nil, nil, nil, nil
        -- Widget history intentionally keeps the disposed shell; its session must be detached.
        assert(weak[1]._session == nil)
        weak[1] = nil
        soak.released_refs[#soak.released_refs + 1] = weak
      else
        widget:focus()
        soak.settled(soak.rows)
      end
      return memory
    end

    ---@return table
    function soak.check_release()
      collectgarbage("collect")
      local remaining = { sessions = 0, data = 0, views = 0 }
      for _, refs in ipairs(soak.released_refs) do
        if refs[2] then remaining.sessions = remaining.sessions + 1 end
        if refs[3] then remaining.data = remaining.data + 1 end
        if refs[4] then remaining.views = remaining.views + 1 end
      end
      return remaining
    end
    soak.open()
  ]=],
    { top + 2, branch }
  )
  local samples, changes = {}, {}
  local name = "a-watch.lua"
  for index = 1, cycles do
    ui:rpc("nvim_exec_lua", "soak.prepare(...)", { index })
    local next_name = name == "a-watch.lua" and "b-watch.lua" or "a-watch.lua"
    assert(
      vim.wait(5000, function()
        return grid:find(name) and not grid:find(next_name)
      end, 1),
      "old watch name is not visible"
    )
    watched = { name = next_name, started = vim.uv.hrtime() }
    assert(vim.uv.fs_rename(directory .. "/" .. name, directory .. "/" .. next_name))
    assert(
      vim.wait(10000, function()
        return watched.flushed ~= nil
      end, 1),
      "watch rename did not reach UI flush"
    )
    changes[#changes + 1] = (watched.flushed - watched.started) / 1000000
    name, watched = next_name, nil
    samples[#samples + 1] = ui:rpc("nvim_exec_lua", "return soak.finish(...)", { index })
    if index % 20 == 0 then
      ui:rpc("nvim_exec_lua", "soak.releases[#soak.releases + 1] = soak.check_release()", {})
    end
    if index % 20 == 0 and index < cycles then
      ui:rpc("nvim_exec_lua", "soak.open()", {})
    end
  end
  table.sort(changes)
  local final = ui:rpc(
    "nvim_exec_lua",
    [[
    bench.dispose()
    local before = { memory = bench.memory(), retained = soak.check_release() }
    -- Compiled LuaJIT traces can own otherwise unreachable closure constants. Keep them during
    -- every cycle and memory sample, then exclude them only from this final ownership assertion.
    jit.flush()
    assert(vim.wait(10000, function()
      collectgarbage("collect")
      for _, refs in ipairs(soak.released_refs) do if next(refs) then return false end end
      return true
    end, 10), "disposed session/data/view remained reachable after trace collection")
    return { memory = bench.memory(), before_trace_flush = before, releases = soak.releases,
      released_sessions = #soak.released_refs, buffers = #vim.api.nvim_list_bufs(), errors = bench.errors }
  ]],
    {}
  )
  assert(#final.errors == 0, vim.inspect(final.errors))
  return {
    cycles = cycles,
    files = entries,
    samples = samples,
    final = final,
    watch_change_to_flush_ms = {
      median = (changes[math.floor((cycles + 1) / 2)] + changes[math.ceil((cycles + 1) / 2)]) / 2,
      p95 = changes[math.ceil(cycles * 0.95)],
      max = changes[#changes],
    },
    ui_flushes = grid.flushes,
    system = vim.uv.os_uname(),
    nvim = vim.version(),
    notes = "One retained session per 20 cycles; Tree/List, fold/expand, refresh, real watch rename, hide/reopen and a second tab every 10 cycles. Memory after hide and full GC; RSS does not establish a leak.",
  }
end, debug.traceback)

if ui then
  ui:close()
end
vim.fn.delete(directory, "rf")
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
