---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.runtime" ---@type string
local root, directory, implementation, entries, branch_entries, mode = ...
vim.api.nvim_set_current_dir(directory)
local runtime = vim.env.VIMRUNTIME
vim.opt.runtimepath = { root, runtime, vim.api.nvim__get_lib_dir() }
vim.opt.packpath = { root, runtime, vim.api.nvim__get_lib_dir() }
package.path = root .. "/?.lua;" .. root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
yoz = assert(
  package.loadlib(root .. "/lua/yoz." .. (vim.uv.os_uname().sysname == "Windows_NT" and "dll" or "so"), "luaopen_yoz")
)()
package.loaded.yoz = yoz
stl, dot, era = require("stl"), require("dot"), require("era")
dot.path.workspace = function()
  return directory
end
dot.path.is_git_repo = function()
  return false
end
bench = { errors = {}, implementation = implementation, entries = entries, branch_entries = branch_entries }
stl.reporter.error = function(value)
  bench.errors[#bench.errors + 1] = value.message
end
stl.reporter.warn = stl.reporter.error
stl.reporter.info = function() end
local Observable = require("stl.c.observable")
local Git = require("era.m.git.state")
Git.refresh = function()
  return stl.c.Future.resolve(nil)
end
local options = {
  name = "performance-comparison",
  root = directory,
  o_width = Observable.from_value(44),
  o_flag_selected = Observable.from_value(false),
  o_flag_viewtype = Observable.from_value(mode),
  o_flag_foldempty = Observable.from_value(false),
  o_flag_hidden = Observable.from_value(true),
}
dot.context.explorer.flag_selected = options.o_flag_selected
dot.context.explorer.flag_viewtype = options.o_flag_viewtype
dot.context.theme.apply_theme({ theme = "rosepine-main", transparency = false })
vim.o.laststatus, vim.o.showtabline = 0, 0
vim.o.swapfile, vim.o.shadafile = false, "NONE"
local Widget = require("era.m.explorer.widget")
local native = implementation == "native"

---@return table|nil
local function current_view()
  return bench.widget and native and bench.widget._views[vim.api.nvim_get_current_tabpage()] or nil
end

---@return integer|nil
local function current_buffer()
  local view = current_view()
  return native and view and view.bufnr or bench.widget and bench.widget:get_bufnr()
end

---@return boolean, integer
local function state_ready()
  if not bench.widget then
    return false, 0
  end
  if native then
    local view, session = current_view(), bench.widget._session
    if not view or not view:frame() or not session then
      return false, 0
    end
    local frame = view:frame()
    local header = frame:header()
    local ready = not session.data._native:is_busy()
      and not view._busy
      and not view._filetree_pending
      and not session._subscriptions._running
      and not session._subscriptions._git
      and next(session._subscriptions._buffers) == nil
      and header.data_revision == session.data:source():revision()
    return ready, header.row_count
  end
  local result = bench.widget:get_render_result()
  return result ~= nil and #result.deferred_file_icons == 0, result and #result.lines or 0
end

---@return nil
local function check()
  local phase = bench.phase
  if not phase or not phase.invoked or phase.done then
    return
  end
  local ready, rows = state_ready()
  phase.observed_rows = rows
  if phase.kind == "cursor" then
    if native then
      local view = current_view()
      ready = ready and view:frame():header().cursor_row == phase.cursor_row
    end
    local winnr = bench.widget:get_winnr(vim.api.nvim_get_current_tabpage())
    ready = ready and vim.api.nvim_win_get_cursor(winnr)[1] == phase.cursor_row
  else
    ready = ready and rows == phase.expected_rows
    if native and phase.kind == "refresh" then
      ready = ready and current_view():frame():header().data_revision ~= phase.source_revision
    elseif native and phase.kind == "empty_git_notification" then
      ready = ready and bench.widget._session._subscriptions._git_revision > phase.git_revision
    elseif not native then
      ready = ready and (bench.widget._render_generation or 0) > phase.generation
    end
  end
  if ready then
    phase.done = vim.uv.hrtime()
  end
end

if not native then
  local render = Widget.__render__
  Widget.__render__ = function(self, ...)
    local result = render(self, ...)
    local phase = bench.phase
    if phase and bench.widget == self then
      local output = self:get_render_result()
      if output and #output.lines == phase.expected_rows then
        phase.body = phase.body or vim.uv.hrtime()
      end
    end
    return result
  end
end

local last_tick = vim.uv.hrtime()
bench.timer = assert(vim.uv.new_timer())
bench.timer:start(
  2,
  2,
  vim.schedule_wrap(function()
    local now = vim.uv.hrtime()
    if bench.phase and bench.phase.started and not bench.phase.done then
      local gap = (now - math.max(last_tick, bench.phase.started)) / 1000000
      bench.phase.max_tick_gap_ms = math.max(bench.phase.max_tick_gap_ms or 0, gap)
    end
    last_tick = now
    check()
  end)
)

---@param kind                          string
---@param expected_rows                 integer
---@param cursor_row                    ?integer
---@return nil
function bench.start(kind, expected_rows, cursor_row)
  local phase = {
    kind = kind,
    expected_rows = expected_rows,
    cursor_row = cursor_row,
    generation = bench.widget and bench.widget._render_generation or 0,
    source_revision = current_view() and current_view():frame():header().data_revision,
    git_revision = native and bench.widget and bench.widget._session._subscriptions._git_revision,
    max_tick_gap_ms = 0,
  }
  bench.phase = phase
  vim.schedule(function()
    phase.started = vim.uv.hrtime()
    if kind == "open" then
      bench.widget = Widget.new(options)
      bench.widget:focus()
    elseif kind == "refresh" then
      phase.future = bench.widget:refresh()
    elseif kind == "empty_git_notification" then
      bench.git_generation = (bench.git_generation or 1000000) + 1
      Git.o_refreshed:next({ generation = bench.git_generation, change_scope = "unknown" }, { force = true })
    elseif kind == "expand" or kind == "collapse" then
      local winnr = bench.widget:get_winnr(vim.api.nvim_get_current_tabpage())
      vim.api.nvim_win_set_cursor(winnr, { 1, 0 })
      if native then
        bench.widget._action:activate()
      else
        bench.widget._action:open()
      end
    elseif kind == "cursor" then
      local winnr = bench.widget:get_winnr(vim.api.nvim_get_current_tabpage())
      local row = vim.api.nvim_win_get_cursor(winnr)[1]
      assert(math.abs(row - cursor_row) == 1)
      vim.api.nvim_input(cursor_row > row and "j" or "k")
    end
    phase.invoked = true
    check()
  end)
end

---@return table
function bench.status()
  check()
  local phase = bench.phase or {}
  return {
    started = phase.started or false,
    body = phase.body or false,
    done = phase.done or false,
    max_tick_gap_ms = phase.max_tick_gap_ms or 0,
    observed_rows = phase.observed_rows,
    expected_rows = phase.expected_rows,
    errors = bench.errors,
  }
end

---@return table
function bench.memory()
  collectgarbage("collect")
  local view = current_view()
  return {
    lua_heap_kib = collectgarbage("count"),
    rss_kib = vim.uv.resident_set_memory() / 1024,
    retained = native and bench.widget and bench.widget._session.data._native:stats() or nil,
    buffer_lines = current_buffer() and vim.api.nvim_buf_line_count(current_buffer()) or 0,
    pid = vim.uv.os_getpid(),
  }
end

---@return nil
function bench.reset_cursor()
  local winnr = bench.widget:get_winnr(vim.api.nvim_get_current_tabpage())
  vim.api.nvim_win_set_cursor(winnr, { 1, 0 })
  vim.api.nvim_win_call(winnr, function()
    vim.cmd("normal! zt")
  end)
end

---@return boolean
function bench.cursor_ready()
  return not native or current_view():frame():header().cursor_row == 1
end

---@return nil
function bench.dispose()
  bench.timer:stop()
  bench.timer:close()
  if bench.widget then
    bench.widget:dispose()
  end
end

return bench.memory()
