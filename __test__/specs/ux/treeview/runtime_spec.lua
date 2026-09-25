---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.treeview.runtime" ---@type string

local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new("ux.treeview.runtime")
local suffix = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
local native = assert(package.loadlib("rust/target/debug/libyoz." .. suffix, "luaopen_yoz"))()
bootstrap.with_yoz(t, native)
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

---@param future                        stl.c.Future
---@return any
local function await(future)
  t.wait_until(function()
    return future:is_done()
  end, 5000, "Treeview Future did not finish")
  t.assert_false(future:is_failed(), future:get_error())
  return future:get_result()
end

---@param value                         any
---@return any
local function applied(value)
  t.assert_eq("Applied", value.kind, vim.inspect(value))
  return value
end

---@return ux.treeview.Data, ux.treeview.State, string, string
local function fixture()
  local data = treeview.new_data()
  applied(await(data:import({
    { key = "root", label = "root", can_expand = true },
    { key = "a", parent = "root", label = "alpha" },
    { key = "b", parent = "root", label = "beta" },
  })))
  local source = data:source()
  local state = await(data:create_state({ kind = "children_of", node = source:id("root") }))
  t.assert_eq("table", type(state), vim.inspect(state))
  return data, state, source:id("a"), source:id("b")
end

t:test("owned input, identity, atomic failure, and exact recursive option", function()
  local data, state, a = fixture()
  local old = state:snapshot()
  local input = { { kind = "update", id = a, label = "changed", fields = { path = "old" } } }
  local future = data:batch(input)
  input[1].label = "mutated after import"
  input[1].fields.path = "mutated"
  applied(await(future))
  t.assert_eq("changed", data:source():node(a).label)
  t.assert_eq("old", data:source():node(a).fields.path)
  t.assert_eq("alpha", old:node(a).label)
  local invalid = await(state:select_node({ a }, "true"))
  t.assert_eq("Rejected", invalid.kind)
  t.assert_eq("InvalidUpdate", invalid.error.code)
  applied(await(state:select_node({ a }, false)))
  local inspect = await(state:inspect_selection())
  t.assert_eq(1, inspect.summary.known_roots)
  local base = data:source():revision()
  invalid = await(data:batch({
    { kind = "update", id = a, label = "not committed" },
    { kind = "insert", key = "a", label = "duplicate" },
  }))
  t.assert_eq("Rejected", invalid.kind)
  t.assert_eq(base, data:source():revision())
  t.assert_eq("changed", data:source():node(a).label)
end)

t:test("viewport guide output is bounded without invalidating the immutable frame", function()
  local data = treeview.new_data()
  local records = { { key = "root", label = "root", can_expand = true } }
  local parent = "root"
  for index = 1, 256 do
    local key = "branch" .. index
    records[#records + 1] = { key = key, parent = parent, label = key, can_expand = true }
    records[#records + 1] = { key = "sibling" .. index, parent = parent, label = "sibling" }
    parent = key
  end
  for index = 1, 40 do
    records[#records + 1] = { key = "leaf" .. index, parent = parent, label = "leaf" }
  end
  applied(await(data:import(records)))
  local source = data:source()
  local state = await(data:create_state({ kind = "children_of", node = source:id("root") }))
  applied(await(state:set_expanded({ source:id("root") }, true, true)))
  local frame
  t.wait_until(function()
    frame = state:snapshot()
    return frame:position(source:id("leaf40")) ~= nil
  end, 5000)
  local first, last = frame:position(source:id("leaf1")), frame:position(source:id("leaf40"))
  local ok, error = pcall(frame.rows, frame, first, last)
  t.assert_false(ok)
  t.assert_true(tostring(error):find("ResourceLimit", 1, true) ~= nil, tostring(error))
  t.assert_eq("leaf", frame:rows(first, first).labels[1])
  t.assert_eq(source:id("leaf40"), frame:node_at(last))
end)

t:test("nil, empty, and partial render contexts share default geometry", function()
  local _, state = fixture()
  local view = state._native:attach()
  t:defer(function()
    view:detach()
  end)
  local async = require("ux.treeview.async")
  local frame = state:snapshot()
  local default = await(async.run(view:plan(nil, frame, nil, nil, true)))
  local expected = default:lines(0, 2, 1024)
  t.assert_true(vim.deep_equal({ "    alpha", "    beta" }, expected))
  for _, context in ipairs({ {}, { separator = "/" }, { indent = 2 }, { slots = 2 } }) do
    local plan = await(async.run(view:plan(nil, frame, context, nil, true)))
    local lines = plan:lines(0, 2, 1024)
    t.assert_true(vim.deep_equal(expected, lines), vim.inspect(context))
  end
end)

t:test("dedicated buffers publish body, delta, decorations, and empty sentinel", function()
  local data, state, a = fixture()
  local errors = {}
  local view = treeview.attach(state, {
    keymaps = false,
    on_error = function(error)
      errors[#errors + 1] = error
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000, "initial frame was not published: " .. vim.inspect(errors))
  t.assert_true(vim.deep_equal({ "    alpha", "    beta" }, vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, true)))
  local tick = vim.api.nvim_buf_get_changedtick(view.bufnr)
  applied(await(state:select_node({ a }, false)))
  t.wait_until(function()
    return view:frame():rows(1, 1).marked[1]
  end, 5000)
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr), "selection must not write body text")
  applied(await(data:batch({ { kind = "update", id = a, label = "renamed" } })))
  t.wait_until(function()
    return vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1] == "    renamed"
  end, 5000)
  t.assert_eq("Delta", view:status().last_plan.mode)
  t.assert_eq(1, view:status().last_plan.written_rows)
  applied(await(state:set_root({ kind = "forest", nodes = {} })))
  t.wait_until(function()
    return view:status().frame.row_count == 0
  end, 5000)
  t.assert_eq(1, vim.api.nvim_buf_line_count(view.bufnr))
  t.assert_nil(view:frame():node_at(1))
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:test("frame preparation preserves the old publication through retries and stale results", function()
  local data, state, a = fixture()
  local delayed, pending, commits, errors = false, {}, {}, {}
  local committed_frame
  ---@param label                        string
  ---@return fun(frame: yoz.ux.treeview.Frame): nil
  local function commit(label)
    return function(frame)
      committed_frame = frame:id()
      commits[#commits + 1] = label
    end
  end
  local view = treeview.attach(state, {
    keymaps = false,
    prepare_frame = function()
      if not delayed then
        return stl.c.Future.resolve(commit("initial"))
      end
      return stl.c.Future.new(function(resolve, reject)
        pending[#pending + 1] = { resolve = resolve, reject = reject }
      end)
    end,
    on_frame = function(frame)
      t.assert_eq(frame:id(), committed_frame, "decorations must be committed before observers run")
    end,
    on_error = function(error)
      errors[#errors + 1] = error
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  local original, tick = view:frame():id(), vim.api.nvim_buf_get_changedtick(view.bufnr)
  delayed = true
  applied(await(data:batch({ { kind = "update", id = a, label = "intermediate" } })))
  t.wait_until(function()
    return #pending == 1
  end, 5000)
  t.assert_eq(original, view:frame():id())
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr))
  pending[1].resolve(false)
  t.wait_until(function()
    return #pending == 2
  end, 5000)
  applied(await(data:batch({ { kind = "update", id = a, label = "latest" } })))
  pending[2].resolve(commit("stale"))
  t.wait_until(function()
    return #pending == 3
  end, 5000)
  t.assert_eq(1, #commits, "a superseded preparation must not run its commit")
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr))
  pending[3].resolve(commit("latest"))
  t.wait_until(function()
    return view:frame():node(a).label == "latest"
  end, 5000)
  t.assert_eq("latest", commits[2])
  t.assert_eq("    latest", vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1])

  local published = view:frame():id()
  applied(await(data:batch({ { kind = "update", id = a, label = "failed" } })))
  t.wait_until(function()
    return #pending == 4
  end, 5000)
  pending[4].reject("decoration preparation failed")
  t.wait_until(function()
    return #errors == 1
  end, 5000)
  t.assert_eq(published, view:frame():id())
  t.assert_eq("    latest", vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1])
  applied(await(data:batch({ { kind = "update", id = a, label = "recovered" } })))
  t.wait_until(function()
    return #pending == 5
  end, 5000)
  pending[5].resolve(commit("recovered"))
  t.wait_until(function()
    return view:frame():node(a).label == "recovered"
  end, 5000)
  t.assert_eq(1, #errors)
end)

t:test("frame preparation rechecks viewport size and ignores detached completions", function()
  local data = treeview.new_data()
  local records = { { key = "root", label = "root", can_expand = true } }
  for index = 1, 40 do
    records[#records + 1] = { key = "item-" .. index, parent = "root", label = "item-" .. index }
  end
  applied(await(data:import(records)))
  local state = await(data:create_state({ kind = "children_of", node = data:source():id("root") }))
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = 0,
    col = 0,
    width = 40,
    height = 6,
    style = "minimal",
  })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  local pending, commits = {}, 0
  local view = treeview.attach(state, {
    winnr = winnr,
    keymaps = false,
    prepare_frame = function(_, _, first, last)
      return stl.c.Future.new(function(resolve)
        pending[#pending + 1] = { first = first, last = last, resolve = resolve }
      end)
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return #pending == 1
  end, 5000)
  vim.api.nvim_win_set_config(winnr, { height = 10 })
  pending[1].resolve(function()
    commits = commits + 1
  end)
  t.wait_until(function()
    return #pending == 2
  end, 5000)
  t.assert_eq(0, commits, "a preparation for the previous viewport must be discarded")
  t.assert_true(pending[2].last > pending[1].last)
  pending[2].resolve(function()
    commits = commits + 1
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  t.assert_eq(1, commits)
  applied(await(data:batch({ { kind = "update", id = data:source():id("item-1"), label = "changed" } })))
  t.wait_until(function()
    return #pending == 3
  end, 5000)
  view:detach()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { "replacement window content" })
  pending[3].resolve(function()
    commits = commits + 1
  end)
  t.assert_eq(1, commits, "a closed view must not apply late decorations")
  t.assert_eq(bufnr, vim.api.nvim_win_get_buf(winnr))
  t.assert_eq("replacement window content", vim.api.nvim_buf_get_lines(bufnr, 0, 1, true)[1])
end)

t:test("column length failure preserves the previous source", function()
  local data = treeview.new_data()
  applied(await(data:import({ keys = { "x", "y" }, labels = { "X", "Y" }, parents = { 0, 0 } })))
  local revision = data:source():revision()
  local result = await(data:import({ keys = { "z", "w" }, labels = { "Z" } }))
  t.assert_eq("Rejected", result.kind)
  t.assert_eq(revision, data:source():revision())
end)

t:test("sparse arrays are rejected before changing source or selection", function()
  local data, state, a = fixture()
  applied(await(state:select_node({ a }, false)))
  local revision = data:source():revision()
  for _, records in ipairs({
    { [0] = { key = "bad", label = "bad" } },
    { [100] = { key = "bad", label = "bad" } },
    { keys = { [100] = "bad" }, labels = { [100] = "bad" } },
    { keys = { "bad" }, labels = { "bad" }, parents = { [100] = 0 } },
  }) do
    t.assert_eq("Rejected", await(data:import(records)).kind)
    t.assert_eq(revision, data:source():revision())
    t.assert_eq(a, data:source():id("a"))
  end
  t.assert_eq("Rejected", await(data:batch({ [100] = { kind = "remove", id = a } })).kind)
  t.assert_eq("Rejected", await(state:select_node({ [100] = a }, false)).kind)
  t.assert_eq(1, await(state:inspect_selection()).summary.known_roots)
  local upload = data:begin_import()
  t.assert_eq("Rejected", upload:append({ [100] = { key = "bad", label = "bad" } }).kind)
  t.assert_eq("Rejected", await(upload:commit()).kind)
  local oversized = data:begin_import()
  t.assert_eq("Rejected", oversized:append({ { key = "large", label = string.rep("x", 2 * 1024 * 1024) } }).kind)
  t.assert_eq(revision, data:source():revision())
end)

t:test("List loads a hidden unknown root and activation preserves Tree expansion", function()
  local calls, activated = 0, nil
  local data = treeview.new_data({
    read_children = function()
      calls = calls + 1
      return {
        records = { { key = "branch", label = "branch", can_expand = true, completeness = "complete" } },
        done = true,
      }
    end,
  })
  applied(await(data:batch({ { kind = "insert", key = "root", label = "root", can_expand = true } })))
  t.assert_eq("unknown", data:source():node(data:source():id("root")).completeness)
  local state = await(data:create_state({ kind = "children_of", node = data:source():id("root") }, { mode = "list" }))
  local view = treeview.attach(state, {
    keymaps = false,
    on_activate = function(_, node)
      activated = node
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() and view:status().frame.row_count == 1
  end, 5000)
  t.assert_eq(1, calls)
  view:activate()
  t.assert_eq(data:source():id("branch"), activated)
  t.assert_false(state:snapshot():rows(1, 1).expanded[1])
end)

t:test("decoration capacity failure preserves the previous publication", function()
  local data, state, a = fixture()
  applied(await(state:set_display({ pattern = "a" })))
  local errors = {}
  local view = treeview.attach(state, {
    keymaps = false,
    on_error = function(err)
      errors[#errors + 1] = err
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  local frame, tick = view:frame():id(), vim.api.nvim_buf_get_changedtick(view.bufnr)
  applied(await(data:batch({ { kind = "update", id = a, label = string.rep("a", 10000) } })))
  t.wait_until(function()
    return #errors > 0
  end, 5000)
  vim.wait(50, function()
    return false
  end)
  t.assert_eq(1, #errors)
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr))
  t.assert_eq(frame, view:frame():id())
  applied(await(data:batch({ { kind = "update", id = a, label = "alpha" } })))
  t.wait_until(function()
    return not view:status().error and state._native:applicable(view:frame(), nil)
  end, 5000)
end)

t:test("view detach does not cancel an accepted selection command", function()
  local _, state, a = fixture()
  local view = treeview.attach(state, {
    keymaps = false,
    on_error = function(error)
      error(error)
    end,
  })
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  local future = state:select_node({ a }, true)
  view:detach()
  applied(await(future))
  t.assert_eq(1, await(state:inspect_selection()).summary.known_roots)
end)

t:test("Visual keeps both UTF-8 endpoints and submits the captured identities", function()
  local data, state, a, b = fixture()
  local root = data:source():id("root")
  local errors = {}
  local view = treeview.attach(state, {
    keymaps = false,
    on_error = function(value)
      errors[#errors + 1] = value
    end,
  })
  t:defer(function()
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  vim.api.nvim_win_set_cursor(view.winnr, { 2, 6 })
  vim.cmd.normal({ args = { "v" }, bang = true })
  vim.api.nvim_win_set_cursor(view.winnr, { 1, 6 })
  applied(await(data:batch({ { kind = "update", id = a, label = "中" } })))
  t.wait_until(function()
    return vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1] == "    中"
  end, 5000)
  t.assert_eq("v", vim.api.nvim_get_mode().mode)
  t.assert_eq(2, vim.fn.getpos("v")[2])
  t.assert_eq(7, vim.fn.getpos("v")[3])
  t.assert_eq(4, vim.api.nvim_win_get_cursor(view.winnr)[2])
  local displayed = view:frame():id()
  applied(await(data:batch({
    {
      kind = "insert",
      key = "middle",
      parent = { id = root },
      position = { before = { id = b } },
      label = "middle",
    },
  })))
  t.wait_until(function()
    return state:snapshot():header().row_count == 3
  end, 5000)
  t.assert_eq(displayed, view:frame():id())
  t.assert_eq(2, vim.api.nvim_buf_line_count(view.bufnr))
  applied(await(view:select("select_node", false)))
  t.wait_until(function()
    return view:status().frame.row_count == 3
  end, 5000)
  local rows = view:frame():rows(1, 3)
  t.assert_true(rows.marked[1])
  t.assert_false(rows.marked[2])
  t.assert_true(rows.marked[3])
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:test("partial buffer failure disables input and resynchronizes the complete frame once", function()
  local data = treeview.new_data()
  local records = { { key = "root", label = "root", can_expand = true } }
  for index = 1, 12 do
    records[#records + 1] = { key = "n" .. index, parent = "root", label = "node" .. index }
  end
  applied(await(data:import(records)))
  local state = await(data:create_state({ kind = "children_of", node = data:source():id("root") }))
  local errors = {}
  local view = treeview.attach(state, {
    keymaps = false,
    on_error = function(value)
      errors[#errors + 1] = value
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  local set_lines = vim.api.nvim_buf_set_lines
  local writes, blocked = 0, nil
  t:patch_table(vim.api, "nvim_buf_set_lines", function(bufnr, first, last, strict, text)
    if bufnr == view.bufnr then
      writes = writes + 1
      blocked = view:select("select_node", true):get_result()
      if writes == 2 then
        error("injected second-splice failure")
      end
    end
    return set_lines(bufnr, first, last, strict, text)
  end)
  applied(await(data:batch({
    { kind = "update", node = "n1", label = "first changed" },
    { kind = "update", node = "n12", label = "last changed" },
  })))
  t.wait_until(function()
    return writes >= 3 and not view:status().desynced
  end, 5000)
  t.assert_eq("Rejected", blocked.kind)
  t.assert_eq("Reset", view:status().last_plan.mode)
  t.assert_eq("    first changed", vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1])
  t.assert_eq("    last changed", vim.api.nvim_buf_get_lines(view.bufnr, 11, 12, true)[1])
  t.assert_true(#errors >= 1)
  t.assert_true(await(state:inspect_selection()).summary.is_empty)
end)

t:test("an external buffer write invalidates mapping until reset", function()
  local _, state = fixture()
  local view = treeview.attach(state, { keymaps = false, on_error = function() end })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  vim.api.nvim_set_option_value("modifiable", true, { buf = view.bufnr })
  vim.api.nvim_buf_set_lines(view.bufnr, 0, -1, true, { "foreign" })
  vim.api.nvim_set_option_value("modifiable", false, { buf = view.bufnr })
  t.assert_nil(view:frame())
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  t.assert_eq("    alpha", vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1])
end)

t:test("PrepareSources Pending finishes once and a task alone can request children", function()
  local Future = require("stl.c.future")
  local read, resolve = Future.new_with_resolver()
  local calls = 0
  local data = treeview.new_data({
    read_children = function()
      calls = calls + 1
      return read
    end,
  })
  applied(await(data:batch({ { kind = "insert", key = "root", label = "root", can_expand = true } })))
  local root = data:source():id("root")
  local state = await(data:create_state({ kind = "children_of", node = root }))
  applied(await(state:select_node({ root }, false)))
  local task = await(state:lock_selection(5000))
  local pending = task:prepare_sources()
  t.assert_eq("Pending", await(pending).kind)
  t.wait_until(function()
    return calls == 1
  end, 5000)
  resolve({ records = { { key = "child", label = "child" } }, done = true })
  t.wait_until(function()
    return data:source():node(root).completeness == "complete"
  end, 5000)
  local ready = await(task:prepare_sources())
  t.assert_eq("Ready", ready.kind, vim.inspect(ready))
  t.assert_eq(0, ready.subtree_roots:len())
  t.assert_eq(1, ready.self_only_nodes:len())
  t.assert_eq("Pending", pending:get_result().kind)
  applied(await(data:batch({ { kind = "update", id = root, label = "new label" } })))
  t.assert_eq("root", ready.source:node(root).label)
  t.assert_eq("root", await(task:prepare_sources()).source:node(root).label)
  applied(await(task:unlock()))
end)

t:test("query generations coalesce pending work and retain only the new result set", function()
  local Future = require("stl.c.future")
  local data = treeview.new_data({ limits = { concurrent_reads = 1 } })
  applied(await(data:import({ { key = "old", label = "old" } })))
  local provider = await(data:create_provider({ kind = "forest" }))
  local requests, resolvers = {}, {}
  local query = await(provider:create_query(function(request)
    requests[#requests + 1] = request
    local future, resolve = Future.new_with_resolver()
    resolvers[#resolvers + 1] = resolve
    return future
  end))
  applied(await(query:start({ pattern = "a" })))
  t.wait_until(function()
    return #requests == 1
  end, 5000)
  applied(await(query:start({ pattern = "ab" })))
  applied(await(query:start({ pattern = "abc" })))
  t.wait_until(function()
    return requests[1].is_cancelled()
  end, 5000)
  resolvers[1]({ records = { { key = "stale", label = "stale" } }, done = true })
  t.wait_until(function()
    return #requests == 2
  end, 5000)
  t.assert_eq("abc", requests[2].pattern)
  t.assert_nil(data:source():id("stale"))
  resolvers[2]({ records = { { key = "new", label = "new" } }, done = true })
  t.wait_until(function()
    return data:source():id("new") ~= nil
  end, 5000)
  t.assert_nil(data:source():id("old"))
  t.assert_eq("complete", query:info().completeness)
  local result = data:source():query_result({ kind = "forest" })
  t.assert_eq("abc", result.pattern)
  t.assert_eq(query:info().result_generation, result.generation)
end)

t:test("private chunks retain ownership and publish only on commit", function()
  local data = treeview.new_data()
  local upload = data:begin_import()
  local chunk = { keys = { "root" }, labels = { "root" }, can_expand = { true } }
  t.assert_eq("NoChange", upload:append(chunk).kind)
  chunk.labels[1] = "changed by caller"
  t.assert_eq(0, data:source():len())
  t.assert_eq("NoChange", upload:append({ keys = { "child" }, labels = { "child" }, parent_keys = { "root" } }).kind)
  applied(await(upload:commit()))
  t.assert_eq("root", data:source():node(data:source():id("root")).label)
  t.assert_eq(2, data:source():len())
  local revision = data:source():revision()
  local bad = data:begin_import()
  t.assert_eq("NoChange", bad:append({ { key = "new", label = "new" } }).kind)
  t.assert_eq("Rejected", bad:append({ keys = { "x" }, labels = {} }).kind)
  t.assert_eq("Rejected", await(bad:commit()).kind)
  t.assert_eq(revision, data:source():revision())
end)

t:test("provider failures preserve classification for children and queries", function()
  local cases = {
    {
      value = { error = { code = "ProviderError", message = "permission denied" } },
      code = "ProviderError",
      message = "permission denied",
    },
    { value = { error = "cannot read" }, code = "ProviderError", message = "cannot read" },
    { thrown = true, code = "ProviderError", message = "provider threw" },
    {
      rejected = true,
      value = "async denied",
      code = "ProviderError",
      message = "async denied",
    },
    { value = 42, code = "InvalidUpdate" },
    { value = {}, code = "InvalidUpdate" },
    { value = { error = { code = "ENOENT", message = "bad code" } }, code = "InvalidUpdate" },
  }
  for _, case in ipairs(cases) do
    local handler = function()
      if case.thrown then
        error("provider threw", 0)
      end
      if case.rejected then
        return require("stl.c.future").reject(case.value)
      end
      return case.value
    end
    local data = treeview.new_data({ read_children = handler })
    applied(await(data:batch({ { kind = "insert", key = "root", label = "root", can_expand = true } })))
    local root = data:source():id("root")
    applied(await(data:request_children({ root })))
    t.wait_until(function()
      return data:source():node(root).load_state == "error"
    end, 5000)
    local failure = data:source():node(root).error
    t.assert_eq(case.code, failure.code)
    if case.message then
      t.assert_eq(case.message, failure.message)
    end
    local query_data = treeview.new_data()
    local provider = await(query_data:create_provider({ kind = "forest" }))
    local query = await(provider:create_query(handler))
    applied(await(query:start({ pattern = "test" })))
    t.wait_until(function()
      return query:info().error ~= nil
    end, 5000)
    failure = query:info().error
    t.assert_eq(case.code, failure.code)
    if case.message then
      t.assert_eq(case.message, failure.message)
    end
  end
end)

t:test("malformed provider errors still end their reserved read and release a preparing task", function()
  local Future = require("stl.c.future")
  local read, fail = Future.new_with_resolver()
  local data = treeview.new_data({
    read_children = function()
      return read
    end,
  })
  applied(await(data:batch({ { kind = "insert", key = "root", label = "root", can_expand = true } })))
  local root = data:source():id("root")
  local state = await(data:create_state({ kind = "children_of", node = root }))
  applied(await(state:select_node({ root }, false)))
  local task = await(state:lock_selection(5000))
  t.assert_eq("Pending", await(task:prepare_sources()).kind)
  fail({ error = { code = "ENOENT", message = "provider error" } })
  t.wait_until(function()
    return not state:status().locked
  end, 5000)
  t.assert_eq("error", data:source():node(root).load_state)
  t.assert_eq("InvalidUpdate", data:source():node(root).error.code)
end)

t:test("List ancestry text remains specific to each root", function()
  local data = treeview.new_data()
  applied(await(data:import({
    { key = "root", label = "root", can_expand = true },
    { key = "src", parent = "root", label = "src", can_expand = true },
    { key = "leaf", parent = "src", label = "文.lua" },
  })))
  local source = data:source()
  local outer = await(
    data:create_state({ kind = "children_of", node = source:id("root") }, { mode = "list", list_text = "ancestry" })
  )
  local inner = await(
    data:create_state({ kind = "children_of", node = source:id("src") }, { mode = "list", list_text = "ancestry" })
  )
  local old = outer:snapshot()
  t.assert_true(vim.deep_equal({ "src", "src/文.lua" }, old:rows(1, 2).labels))
  t.assert_eq("文.lua", inner:snapshot():rows(1, 1).labels[1])
  applied(await(data:batch({ { kind = "update", id = source:id("src"), label = "renamed" } })))
  t.wait_until(function()
    return outer:snapshot():rows(2, 2).labels[1] == "renamed/文.lua"
  end, 5000)
  t.assert_eq("文.lua", inner:snapshot():rows(1, 1).labels[1])
  t.assert_true(vim.deep_equal({ "src", "src/文.lua" }, old:rows(1, 2).labels))
  local invalid = await(
    data:create_state({ kind = "children_of", node = source:id("root") }, { mode = "list", list_text = "unknown" })
  )
  t.assert_eq("Rejected", invalid.kind)
  t.assert_eq("InvalidUpdate", invalid.error.code)
end)

t:test("directory import refreshes ancestry text in the published buffer", function()
  local data = treeview.new_data()
  local records = {
    { key = "root", label = "root", can_expand = true },
    { key = "dir", parent = "root", label = "before", can_expand = true },
    { key = "file", parent = "dir", label = "文.lua" },
  }
  applied(await(data:import(records)))
  local state = await(
    data:create_state(
      { kind = "children_of", node = data:source():id("root") },
      { mode = "list", list_text = "ancestry", show_hidden = false }
    )
  )
  local view = treeview.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  local old = view:frame()
  records[2].label = "after"
  local reply = applied(await(data:import(records)))
  t.wait_until(function()
    return state._native:applicable(view:frame(), reply.revisions.commit)
  end, 5000)
  t.assert_true(vim.deep_equal({ "  after", "  after/文.lua" }, vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, true)))
  t.assert_true(vim.deep_equal({ "before", "before/文.lua" }, old:rows(1, 2).labels))
end)

t:run()
