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
  vim.api.nvim_exec_autocmds("CursorMoved", { group = view._group, buffer = view.bufnr, modeline = false })
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
