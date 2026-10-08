---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.navigation" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local harness = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
local root = vim.env.NVIM_EXPLORER_BENCH_CHECKOUT or harness
local Metrics = assert(loadfile(here .. "/metrics.lua"))()
package.path = harness .. "/?.lua;" .. package.path
local samples = tonumber(arg[1]) or 3
assert(samples >= 1 and samples <= 100 and samples % 1 == 0 and arg[2] == nil)
local UI = require("__test__.support.ui")
local Grid = require("__test__.support.ui_grid")
local directory, ui

---@param path                          string
---@return nil
local function file(path)
  local descriptor = assert(vim.uv.fs_open(path, "wx", 384))
  assert(vim.uv.fs_write(descriptor, "content", 0))
  assert(vim.uv.fs_close(descriptor))
end

---@param grid                          table
---@param path                          string
---@return nil
local function expect_cursor(grid, path)
  local next_check = 0
  assert(
    vim.wait(10000, function()
      local now = vim.uv.hrtime()
      if now < next_check then
        return false
      end
      next_check = now + 20000000
      local ready = ui:rpc(
        "nvim_exec_lua",
        [[
      local path = ...
      local session, view = bench.widget:context()
      assert(#bench.errors == 0, vim.inspect(bench.errors))
      return bench.widget:get_cursor_filepath() == path and view:frame()
        and view:frame():header().cursor_row == vim.api.nvim_win_get_cursor(view.winnr)[1]
        and not view._busy and not session.data._native:is_busy()
    ]],
        { path }
      )
      local target = grid:find(vim.fs.basename(path))
      return ready and target and grid.cursor and grid.cursor[1] == target.grid and grid.cursor[2] == target.row
    end, 10),
    "navigation did not reach its visible target: " .. path
  )
end

local ok, result = xpcall(function()
  local records = {}
  for sample = 1, samples do
    directory = vim.fn.tempname()
    assert(vim.uv.fs_mkdir(directory, 448))
    directory = assert(vim.uv.fs_realpath(directory))
    ui = UI.new({ timeout_ms = 30000 })
    local grid = Grid.new(ui)
    ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
    for cycle = 1, 10 do
      local workspace = string.format("%s/workspace-%02d", directory, cycle)
      local nested = string.format("%s/sub/nested-%02d.txt", workspace, cycle)
      local external = string.format("%s/external-%02d.txt", directory, cycle)
      assert(vim.uv.fs_mkdir(workspace, 448))
      assert(vim.uv.fs_mkdir(workspace .. "/sub", 448))
      file(workspace .. "/a.txt")
      file(nested)
      file(external)
      ui:rpc(
        "nvim_exec_lua",
        [[
        local runtime, root, workspace, first = ...
        if first then
          assert(loadfile(runtime))(root, workspace, "native", 2, 0, "tree")
          bench.start("open", 2)
          assert(vim.wait(10000, function() return bench.phase and bench.phase.done end, 2))
          bench.timer:stop()
          bench.timer:close()
          bench.timer = nil
          ---@param future              stl.c.Future
          ---@return any
          function bench.await(future)
            assert(vim.wait(10000, function() return future:is_done() end, 2))
            assert(not future:is_failed(), future:get_error())
            local value = future:get_result()
            assert(type(value) ~= "table" or value.kind ~= "Rejected", vim.inspect(value))
            return value
          end
        else
          dot.path.workspace = function() return workspace end
          bench.widget = require("era.m.explorer.widget").new({ name = "navigation-acceptance", root = workspace })
          bench.widget:focus()
          assert(vim.wait(10000, function()
            local view = bench.widget._views[vim.api.nvim_get_current_tabpage()]
            return view and view:frame() and view:frame():header().row_count == 2
              and not view._busy and not bench.widget._session.data._native:is_busy()
          end, 2))
        end
        local _, view = bench.widget:context()
        bench.await(view:set_cursor(1))
        vim.api.nvim_input("jmx")
      ]],
        { here .. "/runtime.lua", root, workspace, cycle == 1 }
      )
      expect_cursor(grid, workspace .. "/a.txt")
      ui:rpc(
        "nvim_exec_lua",
        [[
        local nested = ...
        assert(vim.wait(10000, function()
          local session, view = bench.widget:context()
          return session:mode(view:frame()) == "cut"
        end, 2))
        local result = bench.await(bench.widget:reveal(nested))
        assert(result and result.kind == "Applied", vim.inspect(bench.errors))
      ]],
        { nested }
      )
      expect_cursor(grid, nested)
      ui:rpc("nvim_exec_lua", "assert(bench.widget._session:mode() == 'cut')", {})
      assert(vim.fn.delete(workspace, "rf") == 0)
      ui:rpc(
        "nvim_exec_lua",
        [[
        local external = ...
        bench.await(bench.widget:refresh())
        local result = bench.await(bench.widget:reveal(external))
        assert(result and result.kind == "Applied", vim.inspect(bench.errors))
      ]],
        { external }
      )
      expect_cursor(grid, external)
      ui:rpc(
        "nvim_exec_lua",
        [[
        local parent = ...
        assert(bench.widget:get_root_filepath() == parent)
        local session = bench.widget._session
        bench.widget:hide()
        assert(vim.wait(10000, function()
          return session.data:watch_status().roots == 0 and not session.data._native:is_busy()
            and session.data._native:stats().queue_depth == 0
        end, 2))
        bench.widget:dispose()
        bench.widget = nil
        assert(#bench.errors == 0, vim.inspect(bench.errors))
      ]],
        { directory }
      )
    end
    records[#records + 1] = { sample = sample, nested_reveals = 10, removed_roots = 10, released_views = 10 }
    ui:close()
    ui = nil
    assert(vim.fn.delete(directory, "rf") == 0)
    directory = nil
  end
  return {
    records = records,
    memory_measurement = Metrics.memory_description(),
    conditions = "Fresh native process per sample, 110x40 attached UI, ten cycles per process. Typed j/mx then nested reveal preserves cut selection; external removal of the display root, refresh and reveal reaches an existing external file. Cursor and target are checked in UI flushes; hidden views release watches and queued work. Observations are limited to one RPC per 20 ms; this is acceptance, not an A/B latency benchmark.",
  }
end, debug.traceback)
if ui then
  ui:close()
end
if directory then
  vim.fn.delete(directory, "rf")
end
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
