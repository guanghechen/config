---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.treeview.cursor" ---@type string

local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new("ux.treeview.cursor")
local suffix = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
bootstrap.with_yoz(t, assert(package.loadlib("rust/target/debug/libyoz." .. suffix, "luaopen_yoz"))())
bootstrap.with_stl(t, {
  c = { Future = require("stl.c.future") },
  nvim = { fn = require("stl.nvim.fn") },
  reporter = {
    error = function(options)
      error(options.message)
    end,
  },
})
local treeview = require("ux.treeview")
local async = require("ux.treeview.async")
local surface = require("ux.treeview.surface")

---@param future                        stl.c.Future
---@return any
local function await(future)
  t.wait_until(function()
    return future:is_done()
  end, 5000)
  t.assert_false(future:is_failed(), future:get_error())
  local value = future:get_result()
  t.assert_false(type(value) == "table" and value.kind == "Rejected", vim.inspect(value))
  return value
end

---@return ux.treeview.State, ux.treeview.View, string[]
local function fixture()
  local data = treeview.new_data()
  await(data:import({
    { key = "root", label = "root", can_expand = true },
    { key = "a", parent = "root", label = "alpha" },
    { key = "b", parent = "root", label = "beta" },
    { key = "c", parent = "root", label = "gamma" },
  }))
  local source = data:source()
  local state = await(data:create_state({ kind = "children_of", node = source:id("root") }))
  local view = treeview.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil and not view._busy and not view._latest
  end, 5000)
  return state, view, { source:id("a"), source:id("b"), source:id("c") }
end

---@param view                          ux.treeview.View
---@return fun()
local function hold_publication(view)
  local request = surface.request
  return t:patch_table(surface, "request", function(current, ...)
    if current ~= view then
      return request(current, ...)
    end
  end)
end

---@param view                          ux.treeview.View
---@return nil
local function cursor_event(view)
  vim.api.nvim_exec_autocmds("CursorMoved", { group = view._group, buf = view.bufnr, modeline = false })
end

---@param state                         ux.treeview.State
---@param node                          string
---@return nil
local function native_cursor(state, node)
  await(async.run(state._native:dispatch({ kind = "set_cursor", node = node })))
  t.wait_until(function()
    return state:snapshot():header().cursor == node
  end, 5000)
end

t:test("duplicate restored-position events cannot overwrite native navigation before publication", function()
  local state, view, nodes = fixture()
  local frame = view:frame()
  local release = hold_publication(view)
  native_cursor(state, nodes[2])
  t.assert_eq(frame:id(), view:frame():id(), "the displayed frame must still be old")
  local submitted = 0
  local dispatch = state.dispatch
  t:patch_table(state, "dispatch", function(self, command, context)
    if command.kind == "set_cursor" then
      submitted = submitted + 1
    end
    return dispatch(self, command, context)
  end)
  for _ = 1, 3 do
    cursor_event(view)
  end
  await(state:inspect_selection())
  t.assert_eq(0, submitted)
  t.assert_eq(nodes[2], state:snapshot():header().cursor)

  -- A real movement on the displayed frame still supersedes the pending native cursor.
  vim.api.nvim_win_set_cursor(view.winnr, { 3, 0 })
  cursor_event(view)
  t.wait_until(function()
    return state:snapshot():header().cursor == nodes[3]
  end, 5000)
  t.assert_eq(1, submitted)
  release()
  view:_poll()
  t.wait_until(function()
    return view:frame():header().cursor == nodes[3] and vim.api.nvim_win_get_cursor(view.winnr)[1] == 3
  end, 5000)
  cursor_event(view)
  cursor_event(view)
  t.assert_eq(1, submitted, "publication does not echo its restored cursor back to native state")
end)

t:test("cursor publication reuses row reads and only redraws changed consumer output", function()
  local state, view, nodes = fixture()
  local decorations = require("ux.treeview.decorations")
  local prepare = decorations.prepare
  local reads, redraws, prepares, commits = 0, 0, 0, 0
  t:patch_table(decorations, "prepare", function(...)
    reads = reads + 1
    return prepare(...)
  end)
  local redraw = view._redraw
  t:patch_table(view, "_redraw", function(self)
    redraws = redraws + 1
    redraw(self)
  end)
  local unchanged = true
  view._options.prepare_frame = function(_, frame, _, _, rows)
    prepares = prepares + 1
    t.assert_true(rows == view._decorations.rows, "cursor preparation shares the immutable row batch")
    return stl.c.Future.resolve(function(published)
      commits = commits + 1
      t.assert_eq(frame:id(), published:id(), "consumer commits the actual target frame")
      return unchanged
    end)
  end
  local original = view:frame()
  local pending = view:set_cursor(2)
  local immediate = redraws
  await(pending)
  t.wait_until(function()
    return view:frame():header().cursor == nodes[2] and not view._busy and not view._latest
  end, 5000)
  t.assert_eq(0, reads, "cursor-only publication does not export the viewport again")
  t.assert_eq(immediate, redraws, "unchanged consumer output does not request another whole-window redraw")
  t.assert_true(original:same_rows(view:frame()))
  t.assert_eq(1, prepares)
  t.assert_eq(1, commits)

  unchanged = nil
  pending = view:set_cursor(3)
  immediate = redraws
  await(pending)
  t.wait_until(function()
    return view:frame():header().cursor == nodes[3] and not view._busy and not view._latest
  end, 5000)
  t.assert_eq(immediate + 1, redraws, "an ordinary commit callback keeps the conservative redraw")
  t.assert_eq(0, reads)
  t.assert_eq(2, commits)

  unchanged = true
  immediate = redraws
  view:refresh_decorations()
  t.wait_until(function()
    return not view:status().preparing
  end, 5000)
  t.assert_eq(immediate + 1, redraws, "explicit decoration invalidation still redraws")
  t.assert_eq(3, commits)
end)

t:test("a cursor-frame observer can close its window before the redraw decision", function()
  vim.cmd.vsplit()
  local _, view = fixture()
  local winnr = view.winnr
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  local errors = {}
  view._options.on_error = function(error)
    errors[#errors + 1] = error
  end
  view._options.on_frame = function()
    view:detach()
    vim.api.nvim_win_close(winnr, true)
  end
  await(view:set_cursor(2))
  t.wait_until(function()
    return not vim.api.nvim_win_is_valid(winnr)
  end, 5000)
  t.assert_eq(0, #errors, "a completed observer can release the surface without a later redraw failure")
end)

for _, programmatic in ipairs({ false, true }) do
  t:test(
    (programmatic and "programmatic" or "observed user") .. " cursor events are deduplicated after later navigation",
    function()
      local state, view, nodes = fixture()
      local release = hold_publication(view)
      if programmatic then
        await(view:set_cursor(2))
      else
        vim.api.nvim_win_set_cursor(view.winnr, { 2, 0 })
        cursor_event(view)
        t.wait_until(function()
          return state:snapshot():header().cursor == nodes[2]
        end, 5000)
      end
      native_cursor(state, nodes[3])
      cursor_event(view)
      cursor_event(view)
      await(state:inspect_selection())
      t.assert_eq(nodes[3], state:snapshot():header().cursor)
      release()
      view:_poll()
      t.wait_until(function()
        return view:frame():header().cursor == nodes[3] and vim.api.nvim_win_get_cursor(view.winnr)[1] == 3
      end, 5000)
      vim.api.nvim_win_set_cursor(view.winnr, { 1, 0 })
      cursor_event(view)
      t.wait_until(function()
        return state:snapshot():header().cursor == nodes[1]
      end, 5000, "the next actual user movement must not be swallowed")
    end
  )
end

t:run()
