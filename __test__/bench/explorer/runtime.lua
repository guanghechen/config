---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.runtime" ---@type string
local root, directory, implementation, entries, branch_entries, mode, variant = ...
variant = variant or {}
local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local Metrics = assert(loadfile(here .. "/metrics.lua"))()
vim.api.nvim_set_current_dir(directory)
local runtime = vim.env.VIMRUNTIME
vim.opt.runtimepath = { root, runtime, vim.api.nvim__get_lib_dir() }
vim.opt.packpath = { root, runtime, vim.api.nvim__get_lib_dir() }
if variant.lua_root then
  vim.opt.runtimepath:prepend(vim.fs.dirname(variant.lua_root))
end
package.path = root .. "/?.lua;" .. root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
if variant.lua_root then
  package.path = variant.lua_root .. "/?.lua;" .. variant.lua_root .. "/?/init.lua;" .. package.path
end
yoz = assert(
  package.loadlib(
    variant.library
      or vim.env[implementation == "legacy" and "NVIM_EXPLORER_BENCH_BASELINE_NATIVE" or "NVIM_EXPLORER_BENCH_NATIVE"]
      or root .. "/lua/yoz." .. (vim.uv.os_uname().sysname == "Windows_NT" and "dll" or "so"),
    "luaopen_yoz"
  )
)()
package.loaded.yoz = yoz
stl, dot, era = require("stl"), require("dot"), require("era")
dot.path.workspace = function()
  return directory
end
dot.path.is_git_repo = function()
  return variant.git == true
end
bench = { errors = {}, implementation = implementation, entries = entries, branch_entries = branch_entries }
bench.usage = Metrics.usage
stl.reporter.error = function(value)
  bench.errors[#bench.errors + 1] = value.message
  if bench.on_error then
    bench.on_error(value.message)
  end
end
stl.reporter.warn = stl.reporter.error
stl.reporter.info = function() end
local Observable = require("stl.c.observable")
local Git = require("era.m.git.state")
if variant.git then
  Git.setup()
else
  Git.refresh = function()
    return stl.c.Future.resolve(nil)
  end
end
local options = {
  name = "performance-comparison",
  root = directory,
  o_width = Observable.from_value(44),
  o_flag_selected = Observable.from_value(false),
  o_flag_viewtype = Observable.from_value(mode),
  o_flag_foldempty = Observable.from_value(false),
  o_flag_hidden = Observable.from_value(not variant.git),
}
dot.context.explorer.flag_selected = options.o_flag_selected
dot.context.explorer.flag_viewtype = options.o_flag_viewtype
dot.context.theme.apply_theme({ theme = "rosepine-main", transparency = false })
vim.o.laststatus, vim.o.showtabline = 0, 0
vim.o.swapfile, vim.o.shadafile = false, "NONE"
local Widget = require("era.m.explorer.widget")
local native = implementation == "native"
local drawn = {}

---@return table|nil
local function current_view()
  return bench.widget and native and bench.widget._views[vim.api.nvim_get_current_tabpage()] or nil
end

---@return integer|nil
local function current_buffer()
  local view = current_view()
  return native and view and view.bufnr or bench.widget and bench.widget:get_bufnr()
end

---@return string|nil
local function drawing_key()
  local bufnr = current_buffer()
  if not bufnr then
    return nil
  end
  local key = bufnr .. ":" .. vim.api.nvim_buf_get_changedtick(bufnr)
  if native then
    local view = current_view()
    local frame = view and view:frame()
    if not frame then
      return nil
    end
    local annotations = view._filetree_annotations
    return table.concat(
      { key, frame:id(), annotations and annotations.revision or "", view._decoration_revision or 0 },
      ":"
    )
  end
  return key .. ":" .. (bench.widget._render_generation or 0)
end

---@return boolean, integer
local function state_ready()
  if not bench.widget then
    return false, 0
  end
  local winnr = bench.widget:get_winnr(vim.api.nvim_get_current_tabpage())
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return false, 0
  end
  if native then
    local view, session = current_view(), bench.widget._session
    if not view or not view:frame() or not session then
      return false, 0
    end
    local frame = view:frame()
    local header = frame:header()
    local ready = session.data._native:is_settled()
      and view._state._native:applicable(frame)
      and not view._busy
      and not view._decoration_pending
      and not view._filetree_pending
      and not session._subscriptions._running
      and not session._subscriptions._git
      and next(session._subscriptions._buffers) == nil
      and header.data_revision == session.data:source():revision()
    return ready and drawn[view.bufnr] == drawing_key(), header.row_count
  end
  local result = bench.widget:get_render_result()
  return result ~= nil and #result.deferred_file_icons == 0 and drawn[current_buffer()] == drawing_key(),
    result and #result.lines or 0
end
bench.ready, bench.current_view, bench.current_buffer = state_ready, current_view, current_buffer
local last_tick = vim.uv.hrtime()

---@return integer
function bench.selection_count()
  if native then
    local view = current_view()
    local summary = view and view:frame() and view:frame():header().summary
    return summary and summary.known_roots + summary.known_self_only or 0
  end
  return #bench.widget._tree:get_selected_nodes()
end

---@return nil
local function check()
  local phase = bench.phase
  if not phase or not phase.invoked or phase.done or phase.failed then
    return
  end
  phase.readiness_checks = phase.readiness_checks + 1
  local ready, rows = state_ready()
  phase.observed_rows = rows
  if native and phase.requires_refresh then
    local future = phase.refresh_future
    if not future or not future:is_done() or future:is_failed() or not phase.accepted then
      return
    end
    if bench.widget._session.data._native:is_settled() then
      phase.scanned = phase.scanned or vim.uv.hrtime()
    else
      phase.scanned = nil
    end
    ready = ready and phase.scanned ~= nil
  end
  if phase.kind == "cursor" or phase.kind == "scroll" then
    if native then
      local view = current_view()
      ready = ready and view:frame():header().cursor_row == phase.cursor_row
    end
    local winnr = bench.widget:get_winnr(vim.api.nvim_get_current_tabpage())
    ready = ready and vim.api.nvim_win_get_cursor(winnr)[1] == phase.cursor_row
  elseif phase.kind == "selection" or phase.kind == "visual_selection" then
    ready = ready and bench.selection_count() == phase.selected
    if native then
      ready = ready and current_view():frame():header().selection_revision ~= phase.selection_revision
    else
      ready = ready and (bench.widget._render_generation or 0) > phase.generation
    end
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
    if native then
      local frame = current_view():frame()
      local source = frame:source()
      if branch_entries > 0 and not bench.branch_node then
        bench.branch_node = frame:node_at(1)
        assert(source:node(bench.branch_node).label == "a-branch", "fixture branch must be the first row")
      end
      for _, node in ipairs({ frame:header().root.node, bench.branch_node }) do
        local value = source:node(node)
        if value and value.error then
          phase.failed = true
          stl.reporter.error({ message = "Directory scan failed: " .. vim.inspect(value.error) })
          return
        end
      end
    end
    local now = vim.uv.hrtime()
    phase.max_tick_gap_ms = math.max(phase.max_tick_gap_ms, (now - math.max(last_tick, phase.started)) / 1000000)
    phase.done = now
    local usage = Metrics.usage()
    phase.cpu_ms = (usage.cpu_us - phase.usage.cpu_us) / 1000
    phase.main_cpu_ms = usage.main_us and (usage.main_us - phase.usage.main_us) / 1000
    if bench.on_phase then
      bench.on_phase(bench.status())
    end
  end
end

local painting
vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace("explorer-benchmark-draw"), {
  on_win = function(_, _, bufnr)
    if bufnr == current_buffer() then
      painting = { bufnr = bufnr, key = drawing_key() }
    end
    return false
  end,
  on_end = function()
    if painting then
      drawn[painting.bufnr] = painting.key
      painting = nil
      -- Include the final viewport callbacks, even when on_frame precedes their first redraw.
      vim.schedule(check)
    end
  end,
})

vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, { callback = check })
if native then
  local Data = require("ux.filetree.data")
  local refresh = Data.refresh
  Data.refresh = function(self, state)
    local future = refresh(self, state)
    local phase = bench.phase
    if
      phase
      and not phase.done
      and phase.requires_refresh
      and bench.widget
      and bench.widget._session
      and bench.widget._session.data == self
    then
      phase.refresh_future, phase.accepted, phase.scanned = future, nil, nil
      future:finally(function(ok, value)
        if phase.refresh_future ~= future then
          return
        end
        if not ok or type(value) == "table" and value.kind == "Rejected" then
          stl.reporter.error({ message = "Refresh request failed: " .. vim.inspect(value) })
          return
        end
        phase.accepted = vim.uv.hrtime()
        check()
      end)
    end
    return future
  end
  local Filetree = require("ux.filetree")
  local attach = Filetree.attach
  Filetree.attach = function(state, props)
    local on_frame = props.on_frame
    props.on_frame = function(frame)
      if on_frame then
        on_frame(frame)
      end
      check()
    end
    return attach(state, props)
  end
else
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
    check()
    return result
  end
end

---@return nil
function bench.tick()
  local now = vim.uv.hrtime()
  if bench.phase and bench.phase.started and not bench.phase.done then
    local gap = (now - math.max(last_tick, bench.phase.started)) / 1000000
    bench.phase.max_tick_gap_ms = math.max(bench.phase.max_tick_gap_ms or 0, gap)
  end
  last_tick = now
  check()
end

bench.timer = assert(vim.uv.new_timer())
bench.timer:start(2, 2, vim.schedule_wrap(bench.tick))

---@param kind                          string
---@param expected_rows                 integer
---@param cursor_row                    ?integer
---@param selected                      ?integer
---@return nil
function bench.start(kind, expected_rows, cursor_row, selected)
  local phase = {
    kind = kind,
    requires_refresh = kind == "open" or kind == "reopen" or kind == "refresh",
    expected_rows = expected_rows,
    cursor_row = cursor_row,
    generation = bench.widget and bench.widget._render_generation or 0,
    source_revision = current_view() and current_view():frame():header().data_revision,
    selection_revision = current_view() and current_view():frame():header().selection_revision,
    selected = selected,
    git_revision = native and bench.widget and bench.widget._session._subscriptions._git_revision,
    max_tick_gap_ms = 0,
    readiness_checks = 0,
  }
  bench.phase = phase
  vim.schedule(function()
    phase.usage = Metrics.usage()
    phase.started = vim.uv.hrtime()
    if bench.on_started then
      bench.on_started(phase.started)
    end
    if kind == "open" then
      bench.widget = Widget.new(options)
      bench.widget:focus()
    elseif kind == "reopen" then
      bench.widget:focus()
    elseif kind == "refresh" then
      phase.future = bench.widget:refresh()
    elseif kind == "empty_git_notification" then
      bench.git_generation = (bench.git_generation or 1000000) + 1
      Git.o_refreshed:next({ generation = bench.git_generation, change_scope = "unknown" }, { force = true })
    elseif kind == "expand" or kind == "collapse" then
      local winnr = bench.widget:get_winnr(vim.api.nvim_get_current_tabpage())
      vim.api.nvim_win_set_cursor(winnr, { cursor_row or 1, 0 })
      if native then
        bench.branch_node = current_view():frame():node_at(cursor_row or 1)
        bench.widget._action:activate()
      else
        bench.widget._action:open()
      end
    elseif kind == "list" then
      vim.api.nvim_input("t2")
    elseif kind == "cursor" then
      local winnr = bench.widget:get_winnr(vim.api.nvim_get_current_tabpage())
      local row = vim.api.nvim_win_get_cursor(winnr)[1]
      assert(math.abs(row - cursor_row) == 1)
      vim.api.nvim_input(cursor_row > row and "j" or "k")
    elseif kind == "scroll" then
      vim.api.nvim_input(tostring(cursor_row) .. "gg")
    elseif kind == "selection" then
      vim.api.nvim_input("<Tab>")
    elseif kind == "visual_selection" then
      vim.api.nvim_input("V" .. tostring(selected - 1) .. "j<Tab>")
    end
    phase.invoked = true
    check()
  end)
end

---@return table
function bench.status()
  local phase = bench.phase or {}
  return {
    started = phase.started or false,
    body = phase.body or false,
    done = phase.done or false,
    accepted = phase.accepted or false,
    scanned = phase.scanned or false,
    max_tick_gap_ms = phase.max_tick_gap_ms or 0,
    cpu_ms = phase.cpu_ms,
    main_cpu_ms = phase.main_cpu_ms,
    readiness_checks = phase.readiness_checks,
    observed_rows = phase.observed_rows,
    expected_rows = phase.expected_rows,
    errors = bench.errors,
    selected = (phase.kind == "selection" or phase.kind == "visual_selection") and bench.selection_count() or nil,
  }
end

---@return table
function bench.memory()
  collectgarbage("collect")
  local result = Metrics.memory()
  result.retained = native and bench.widget and bench.widget._session and bench.widget._session.data._native:stats()
    or nil
  result.buffer_lines = current_buffer() and vim.api.nvim_buf_line_count(current_buffer()) or 0
  result.pid = vim.uv.os_getpid()
  return result
end

---@param row                           ?integer
---@return nil
function bench.reset_cursor(row)
  row = row or 1
  local winnr = bench.widget:get_winnr(vim.api.nvim_get_current_tabpage())
  vim.api.nvim_win_set_cursor(winnr, { row, 0 })
  vim.api.nvim_win_call(winnr, function()
    vim.cmd("normal! zt")
  end)
end

---@param row                           ?integer
---@return boolean
function bench.cursor_ready(row)
  return not native or current_view():frame():header().cursor_row == (row or 1)
end

---@param row                           integer
---@return string
function bench.row_marker(row)
  local line = vim.api.nvim_buf_get_lines(current_buffer(), row - 1, row, false)[1]
  return assert(
    line:match("file%-%d+%.lua")
      or line:match("inside%-%d+%.lua")
      or line:match("directory%-%d+")
      or line:match("a%-branch")
  )
end

---@return nil
function bench.clear_selection()
  vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  if native then
    bench.clearing = bench.widget._session.state:clear_selection()
  else
    bench.widget._tree:clear_selection()
    bench.widget:refresh()
  end
end

---@return boolean
function bench.selection_cleared()
  if bench.clearing then
    assert(not bench.clearing:is_failed(), bench.clearing:get_error())
    if not bench.clearing:is_done() then
      return false
    end
  end
  return state_ready()
    and bench.selection_count() == 0
    and (
      not native
      or current_view():frame():header().selection_revision
        == bench.widget._session.state:snapshot():header().selection_revision
    )
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
