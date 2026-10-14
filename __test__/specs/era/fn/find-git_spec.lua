---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.fn.find_git" ---@type string

require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new("era.fn.find_git")
local support = require("__test__.support.git_files")
local Widget = require("era.m.git_files")

---@return table
local function fixture()
  local root = support.repo(t)
  support.write(root, "dir/mixed.lua", { "one", "two", "three", "staged" })
  support.git(root, { "add", "dir/mixed.lua" })
  support.write(root, "dir/mixed.lua", { "one", "two", "three", "staged", "unstaged" })
  local state = support.widget(t, root)
  state.collect = era.m.git.status.collect
  state.snapshot = support.await(state.collect({ include_numstat = true }))
  state.requests = {}
  t:patch_table(era.m.git.status, "collect", function(options, token)
    local request = { options = options, token = token }
    request.future = stl.c.Future.new(function(resolve, reject)
      request.resolve, request.reject = resolve, reject
    end)
    state.requests[#state.requests + 1] = request
    return request.future
  end)
  t:defer(function()
    state.widget:dispose()
    for _, request in ipairs(state.requests) do
      if not request.future:is_done() then
        request.reject("cancelled")
      end
    end
  end)
  return state
end

---@param state                         table
---@return nil
local function show(state)
  state.widget:toggle()
  state.requests[#state.requests].resolve(state.snapshot)
  support.ready(state.widget)
  t.assert_true(state.widget:isvisible())
end

t:test("find-git owns one reusable dedicated widget and recreates it after disposal", function()
  local widgets = {}
  t:patch_table(Widget, "new", function()
    local widget = { toggles = 0, disposed = false }
    widget.isdisposed = function()
      return widget.disposed
    end
    widget.toggle = function()
      widget.toggles = widget.toggles + 1
    end
    widgets[#widgets + 1] = widget
    return widget
  end)
  local find = assert(loadfile("lua/era/fn/find-git.lua"))()
  find()
  find()
  t.assert_eq(1, #widgets)
  t.assert_eq(2, widgets[1].toggles)
  widgets[1].disposed = true
  find()
  t.assert_eq(2, #widgets)
end)

t:test("opening coalesces pending requests and asks for both sides' numstat", function()
  local state = fixture()
  state.widget:toggle()
  state.widget:toggle()
  t.assert_eq(1, #state.requests)
  t.assert_true(state.requests[1].options.include_numstat)
  state.requests[1].resolve(state.snapshot)
  support.ready(state.widget)
  t.assert_true(state.widget.panes.staged.result:isvisible())
  t.assert_true(state.widget.panes.unstaged.result:isvisible())
  t.assert_true(state.widget.input:isvisible())
  t.assert_true(state.widget.input:isfocused())
  t.assert_true(state.widget._preview_enabled)
  t.assert_eq(vim.o.columns >= 88, state.widget.preview.surface:isvisible())
  t.assert_eq(1, #state.requests)
  state.widget:toggle()
  t.assert_false(state.widget:isvisible())
end)

t:test("hide and disposal cancel late results without reopening panes or retaining observers", function()
  local state = fixture()
  state.widget:toggle()
  local first = state.requests[1]
  state.widget:hide()
  t.assert_true(first.token:is_cancelled())
  first.resolve(state.snapshot)
  t.assert_false(state.widget:isvisible())
  state.refreshed:next(1)
  t.assert_eq(1, #state.requests, "hidden widgets do not collect Git status")
  state.widget:toggle()
  local second = state.requests[2]
  state.widget:dispose()
  second.resolve(state.snapshot)
  state.refreshed:next(2)
  t.assert_eq(2, #state.requests)
  t.assert_eq(0, #state.warnings)
end)

t:test("refresh failure retains both published trees and rejects file transfers until retry", function()
  local state = fixture()
  show(state)
  local before = state.widget.panes.staged.tree:frame():header().data_revision
  state.widget:refresh(false)
  state.requests[2].reject("Git status failed")
  t.assert_true(state.widget._failed)
  t.assert_eq(before, state.widget.panes.staged.tree:frame():header().data_revision)
  t.assert_eq(1, #state.warnings)
  state.widget:focus("staged")
  t.assert_nil(state.widget:transfer("staged"))
  state.widget:refresh(false)
  state.requests[3].resolve(state.snapshot)
  support.ready(state.widget)
  t.assert_false(state.widget._failed)
end)

t:test("older completions cannot clear newer refresh requests", function()
  local state = fixture()
  show(state)
  state.widget:refresh(false)
  state.refreshed:next(1)
  t.wait_until(function()
    return #state.requests == 3
  end, 1000)
  t.assert_eq(3, #state.requests)
  state.requests[2].resolve(state.snapshot)
  t.assert_true(state.widget._request ~= nil)
  t.assert_true(state.requests[2].token:is_cancelled())
  state.requests[3].resolve(state.snapshot)
  support.ready(state.widget)
end)

t:test("changing workspace while opening discards the old request and allows reopening", function()
  local state = fixture()
  state.widget:toggle()
  local root = support.repo(t)
  state.root = root
  state.requests[1].resolve(state.snapshot)
  t.assert_nil(state.widget._request)
  t.assert_false(state.widget:isvisible())
  local snapshot = support.await(state.collect({ include_numstat = true }))
  state.widget:toggle()
  state.requests[2].resolve(snapshot)
  support.ready(state.widget)
  t.assert_eq(root, state.widget._root)
  t.assert_eq(0, state.widget.panes.staged.tree.totals.count)
  t.assert_eq(0, #state.warnings)
end)

t:test("switching to a nested repository resets each display root to that workspace", function()
  local state = fixture()
  show(state)
  state.widget.input:set_content("mixed")
  support.git(state.root, { "init", "-q", "nested" })
  state.root = state.root .. "/nested"
  support.write(state.root, "inside.lua", { "nested" })
  local snapshot = support.await(state.collect({ include_numstat = true }))
  state.widget:refresh(false)
  state.requests[#state.requests].resolve(snapshot)
  support.ready(state.widget)
  for _, pane in pairs(state.widget.panes) do
    t.assert_eq(require("era.view.result_paths").key(state.root), pane.tree:root_key())
  end
  t.assert_eq("", state.widget._query)
  t.assert_eq("", vim.api.nvim_buf_get_lines(state.widget.input:get_bufnr(), 0, 1, false)[1])
  t.assert_eq(0, #state.warnings, vim.inspect(state.warnings))
end)

t:run()
