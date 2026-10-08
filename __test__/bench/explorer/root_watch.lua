---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.root_watch" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local harness = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
local root = vim.env.NVIM_EXPLORER_BENCH_CHECKOUT or harness
local Metrics = assert(loadfile(here .. "/metrics.lua"))()
package.path = harness .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local samples = tonumber(arg[1]) or 3
local library = arg[2] and assert(vim.uv.fs_realpath(arg[2]))
  or vim.env.NVIM_EXPLORER_BENCH_NATIVE
  or root .. "/lua/yoz.so"
assert(vim.uv.os_uname().sysname == "Darwin", "recursive root-watch acceptance requires macOS")
assert(samples >= 1 and samples <= 100 and samples % 1 == 0 and arg[3] == nil)
local UI = require("__test__.support.ui")
local Grid = require("__test__.support.ui_grid")
local records, screens = {}, {}
local directory, ui, grid

---@param code                          string
---@param arguments                     ?any[]
---@return any
local function execute(code, arguments)
  return ui:rpc("nvim_exec_lua", code, arguments or {})
end

---@param predicate                     fun(): boolean
---@param message                       string
---@return nil
local function until_(predicate, message)
  assert(vim.wait(15000, predicate, 5), message)
end

---@param path                          string
---@return nil
local function file(path)
  local descriptor = assert(vim.uv.fs_open(path, "wx", 384))
  assert(vim.uv.fs_close(descriptor))
end

---@param label                         string
---@return nil
local function screen(label)
  local rows = {}
  for _, cells in ipairs(grid.grids[1].rows) do
    local text = {}
    for _, cell in ipairs(cells) do
      text[#text + 1] = cell[1]
    end
    rows[#rows + 1] = table.concat(text):gsub("%s+$", "")
  end
  screens[#screens + 1] = { label = label, rows = rows }
end

---@param roots                         integer
---@param directories                   integer
---@return table
local function watching(roots, directories)
  local status
  until_(function()
    status = execute([[
      local session, view = bench.widget:context()
      local status = session.data:watch_status()
      return { roots = status.roots, directories = status.directories, limited = status.limited,
        error = status.error, busy = session.data._native:is_busy() or view._busy,
        queue = session.data._native:stats().queue_depth }
    ]])
    return status.roots == roots and status.directories == directories and not status.busy
  end, "unexpected watch coverage")
  assert(not status.error and not status.limited, vim.inspect(status))
  return status
end

---@param path                          string
---@return nil
local function reveal(path)
  execute("bench.await(bench.widget:reveal(...))", { path })
  until_(function()
    return execute(
      [[
      local path = ...
      local _, view = bench.widget:context()
      return bench.widget:get_cursor_filepath() == path and view:frame() and not view._busy
        and view:frame():header().cursor_row == vim.api.nvim_win_get_cursor(view.winnr)[1]
    ]],
      { path }
    )
  end, "cursor did not reach " .. path)
  execute([[
    local _, view = bench.widget:context()
    vim.api.nvim_win_call(view.winnr, function() vim.cmd("normal! zz") end)
  ]])
end

local ok, failure = xpcall(function()
  for sample = 1, samples do
    directory = vim.fn.tempname()
    assert(vim.uv.fs_mkdir(directory, 448))
    directory = assert(vim.uv.fs_realpath(directory))
    local workspace = directory .. "/workspace"
    assert(vim.uv.fs_mkdir(workspace, 448))
    for index = 1, 96 do
      local branch = string.format("%s/branch-%03d", workspace, index)
      assert(vim.uv.fs_mkdir(branch, 448))
      file(string.format("%s/seed-%03d", branch, index))
    end
    ui = UI.new({ timeout_ms = 30000 })
    grid = Grid.new(ui)
    ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
    execute(
      [[
      local runtime, root, workspace, library = ...
      assert(loadfile(runtime))(root, workspace, "native", 96, 0, "tree", { library = library })
      bench.start("open", 96)
      assert(vim.wait(15000, function() return bench.phase and bench.phase.done end, 1))
      bench.timer:stop()
      bench.timer:close()
      bench.timer = nil
      ---@param future                  stl.c.Future
      ---@return any
      function bench.await(future)
        assert(vim.wait(15000, function() return future:is_done() end, 1))
        assert(not future:is_failed(), future:get_error())
        local result = future:get_result()
        assert(type(result) ~= "table" or result.kind ~= "Rejected", vim.inspect(result))
        return result
      end
      ---@return table
      function bench.usage()
        local value = vim.uv.getrusage()
        return { at = vim.uv.hrtime(), cpu_us = (value.utime.sec + value.stime.sec) * 1000000
          + value.utime.usec + value.stime.usec, process_memory_bytes = vim.uv.resident_set_memory() }
      end
      local session = bench.widget._session
      local nodes = {}
      for index = 1, 96 do
        nodes[index] = bench.await(session.data:resolve(string.format("%s/branch-%03d", workspace, index))):node()
      end
      bench.first = nodes[1]
      bench.await(session.state:set_expanded(nodes, true, false))
    ]],
      { here .. "/runtime.lua", root, workspace, library }
    )
    local record = { sample = sample, wide = watching(1, 97), cases = {} }
    records[#records + 1] = record
    until_(function()
      return execute("return select(2, bench.widget:context()):frame():header().row_count") == 192
    end, "expanded directories were not displayed")
    vim.wait(500, function()
      return false
    end, 50)
    local before, redraws = execute("collectgarbage('collect'); return bench.usage()"), ui.redraws
    vim.wait(3000, function()
      return false
    end, 50)
    local after = execute("return bench.usage()")
    record.idle = {
      wall_ms = (after.at - before.at) / 1000000,
      cpu_ms = (after.cpu_us - before.cpu_us) / 1000,
      process_memory_mib = after.process_memory_bytes / 1048576,
      redraws = ui.redraws - redraws,
    }

    local last = workspace .. "/branch-096"
    reveal(last .. "/seed-096")
    file(last .. "/watch-created")
    until_(function()
      return grid:find("watch-created") ~= nil
    end, "creation beyond the old directory cap was not displayed")
    assert(vim.uv.fs_rename(last .. "/watch-created", last .. "/watch-renamed"))
    until_(function()
      return grid:find("watch-renamed") ~= nil and grid:find("watch-created") == nil
    end, "external rename was not displayed")
    assert(vim.uv.fs_unlink(last .. "/watch-renamed"))
    until_(function()
      return grid:find("watch-renamed") == nil
    end, "external deletion was not displayed")
    assert(vim.uv.fs_rename(last, workspace .. "/branch-last"))
    until_(function()
      return grid:find("branch-last") ~= nil and grid:find("branch-096") == nil
    end, "directory rename was not displayed")
    file(workspace .. "/branch-last/after-rename")
    until_(function()
      return grid:find("after-rename") ~= nil
    end, "renamed directory lost event delivery")
    screen("wide-events-" .. sample)
    assert(vim.fn.delete(workspace .. "/branch-last", "rf") == 0)
    until_(function()
      return grid:find("branch-last") == nil and grid:find("after-rename") == nil
    end, "deleted directory stayed visible")
    watching(1, 96)
    record.cases[#record.cases + 1] = "wide-create-rename-delete"

    local first = workspace .. "/branch-001"
    reveal(first .. "/seed-001")
    execute("bench.await(bench.widget._session.state:set_expanded({ bench.first }, false, false))")
    watching(1, 95)
    file(first .. "/while-closed")
    vim.wait(450, function()
      return false
    end, 50)
    assert(grid:find("while-closed") == nil, "collapsed children were displayed")
    execute("bench.await(bench.widget._session.state:set_expanded({ bench.first }, true, false))")
    until_(function()
      return grid:find("while-closed") ~= nil
    end, "reopening reused stale cached children")
    watching(1, 96)
    record.cases[#record.cases + 1] = "closed-cache-reread"

    local external, alias = directory .. "/external", workspace .. "/external-link"
    assert(vim.uv.fs_mkdir(external, 448))
    assert(vim.uv.fs_mkdir(external .. "/target", 448))
    file(external .. "/target/external-seed")
    assert(vim.uv.fs_symlink(external .. "/target", alias))
    until_(function()
      return execute("return select(2, bench.widget:context()):frame():header().row_count") == 192
    end, "external link entry was not discovered")
    reveal(alias .. "/external-seed")
    record.external = watching(2, 98)
    file(external .. "/target/external-created")
    until_(function()
      return grid:find("external-created") ~= nil
    end, "external target creation was not displayed")
    assert(vim.fn.delete(external .. "/target", "rf") == 0)
    until_(function()
      return grid:find("external-created") == nil and grid:find("external-seed") == nil
    end, "missing symlink target stayed visible")
    watching(2, 97)
    assert(vim.uv.fs_mkdir(external .. "/target", 448))
    file(external .. "/target/external-restored")
    until_(function()
      return grid:find("external-restored") ~= nil
    end, "restored symlink target was not displayed")
    watching(2, 98)
    record.cases[#record.cases + 1] = "external-root-recovery"
    screen("external-root-" .. sample)

    execute("bench.await(bench.widget:set_root(...))", { first })
    record.narrow = watching(1, 1)
    reveal(first .. "/seed-001")
    file(first .. "/zz-narrow-event")
    until_(function()
      return grid:find("narrow-event") ~= nil
    end, "narrowing the view lost workspace event delivery")
    record.cases[#record.cases + 1] = "narrow-root"
    execute("bench.widget:hide()")
    until_(function()
      return execute([[
        local data = bench.widget._session.data
        local status = data:watch_status()
        return status.roots == 0 and status.directories == 0
          and not data._native:is_busy() and data._native:stats().queue_depth == 0
      ]])
    end, "hidden Explorer retained subscriptions or work")
    execute([[
      bench.widget:dispose()
      assert(#bench.errors == 0, vim.inspect(bench.errors))
      assert(vim.v.errmsg == "", vim.v.errmsg)
      vim.schedule(function() vim.cmd("qa!") end)
    ]])
    until_(function()
      return ui._exited
    end, "Neovim did not exit")
    assert(ui.stderr == "", ui.stderr)
    record.cases[#record.cases + 1] = "hide-dispose-exit"
    ui:close()
    ui = nil
    assert(vim.fn.delete(directory, "rf") == 0)
    directory = nil
    io.stderr:write("Completed recursive root watch sample ", sample, "\n")
  end
end, debug.traceback)
if not ok and ui then
  local captured, state = pcall(
    execute,
    [[
    local session, view = bench.widget:context()
    local status, frame = session.data:watch_status(), view:frame()
    return { roots = status.roots, directories = status.directories, limited = status.limited,
      error = status.error, first_children = session.data:source():node(bench.first).child_count,
      row_count = frame:header().row_count, cursor_row = frame:header().cursor_row,
      lines = vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, false), errors = bench.errors }
  ]]
  )
  if captured then
    io.stderr:write(vim.inspect(state), "\n")
  end
  screen("failure")
  io.stderr:write(vim.inspect(screens[#screens]), "\n")
end
if ui then
  ui:close()
end
if directory then
  vim.fn.delete(directory, "rf")
end
assert(ok, failure)
io.stdout:write(
  vim.json.encode({
    records = records,
    screens = screens,
    nvim = vim.version(),
    memory_measurement = Metrics.memory_description(),
    library = library,
    conditions = "Actual Explorer Widget; 96 expanded directories; macOS recursive roots; 110x40 attached UI; external filesystem changes verified through grid flushes. Idle is 3 s without parent polling, after 500 ms settling; fixture timer, Git collection and LSP are disabled.",
  }),
  "\n"
)
