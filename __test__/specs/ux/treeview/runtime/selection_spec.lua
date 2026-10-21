local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new()
bootstrap.with_native(t)
local treeview = require("ux.treeview")
local support = require("__test__.support.treeview")
local fixture = support.fixture

t:test("marked aggregation validates dense identities and keeps the captured frame", function()
  local data, state, a, b = fixture()
  local old = state:snapshot()
  t.assert_true(old:all_marked({}))
  t.assert_false(old:all_marked({ a }))
  t.assert_false(old:all_marked({ a, a }))
  support.applied(state:select_node({ data:source():id("root") }, true))
  t.wait_until(function()
    return state:snapshot():header().state_revision == state:status().revisions.state
  end, 5000)
  local selected = state:snapshot()
  t.assert_true(selected:all_marked({ a, b, a }))
  t.assert_false(old:all_marked({ a, b }))
  support.applied(state:deselect_node({ b }, false))
  t.wait_until(function()
    return state:snapshot():header().state_revision == state:status().revisions.state
  end, 5000)
  local mixed = state:snapshot()
  t.assert_false(mixed:all_marked({ a, b }))
  t.assert_false(mixed:all_marked({ b, a }))
  t.assert_true(mixed:all_marked({ a, a }))
  support.applied(data:batch({ { kind = "remove", id = a } }))
  t.wait_until(function()
    return state:snapshot():header().data_revision == data:source():revision()
  end, 5000)
  local removed = state:snapshot()
  local ok, failure = pcall(removed.all_marked, removed, { b, a })
  t.assert_false(ok)
  t.assert_true(tostring(failure):find("MissingNode", 1, true) ~= nil, tostring(failure))
  t.assert_true(selected:all_marked({ a, b }))
  t.assert_true(mixed:all_marked({ a }))
  for _, nodes in ipairs({ false, { [0] = b }, { [100] = b }, { b, "invalid" } }) do
    ok, failure = pcall(removed.all_marked, removed, nodes)
    t.assert_false(ok)
    t.assert_true(tostring(failure):find("InvalidUpdate", 1, true) ~= nil, tostring(failure))
  end
end)

t:test("marked aggregation accepts ranges larger than an export page within the input limit", function()
  local data = treeview.new_data()
  local records = { { key = "root", label = "root", can_expand = true } }
  for index = 1, 1100 do
    local key = "item-" .. index
    records[#records + 1] = { key = key, parent = "root", label = key }
  end
  support.applied(data:import(records))
  local source = data:source()
  local state = t.await(data:create_state({ kind = "children_of", node = source:id("root") }))
  support.applied(state:select_node({ source:id("root") }, true))
  t.wait_until(function()
    return state:snapshot():header().state_revision == state:status().revisions.state
  end, 5000)
  local frame, ids = state:snapshot(), {}
  for index = 1, 1100 do
    ids[index] = source:id("item-" .. index)
  end
  t.assert_true(frame:all_marked(ids))
  for index = 1101, 200000 do
    ids[index] = ids[1]
  end
  t.assert_true(frame:all_marked(ids))
  ids[200001] = ids[1]
  local ok, failure = pcall(frame.all_marked, frame, ids)
  t.assert_false(ok)
  t.assert_true(tostring(failure):find("ResourceLimit", 1, true) ~= nil, tostring(failure))
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
  support.applied(future)
  t.assert_eq(1, t.await(state:inspect_selection()).summary.known_roots)
end)

for _, mode in ipairs({ "v", "V", "<C-v>" }) do
  t:test(mode .. " keeps both UTF-8 endpoints and submits the captured identities", function()
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
    vim.cmd.normal({ args = { vim.keycode(mode) }, bang = true })
    vim.api.nvim_win_set_cursor(view.winnr, { 1, 6 })
    support.applied(data:batch({ { kind = "update", id = a, label = "中" } }))
    t.wait_until(function()
      return vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1] == "    中"
    end, 5000)
    t.assert_eq(vim.keycode(mode), vim.api.nvim_get_mode().mode)
    t.assert_eq(2, vim.fn.getpos("v")[2])
    t.assert_eq(7, vim.fn.getpos("v")[3])
    t.assert_eq(4, vim.api.nvim_win_get_cursor(view.winnr)[2])
    local displayed = view:frame():id()
    support.applied(data:batch({
      {
        kind = "insert",
        key = "middle",
        parent = { id = root },
        position = { before = { id = b } },
        label = "middle",
      },
    }))
    t.wait_until(function()
      return state:snapshot():header().row_count == 3
    end, 5000)
    t.assert_eq(displayed, view:frame():id())
    t.assert_eq(2, vim.api.nvim_buf_line_count(view.bufnr))
    support.applied(view:select("select_node", false))
    t.wait_until(function()
      return view:status().frame.row_count == 3
    end, 5000)
    local rows = view:frame():rows(1, 3)
    t.assert_true(rows.marked[1])
    t.assert_false(rows.marked[2])
    t.assert_true(rows.marked[3])
    t.assert_eq("n", vim.api.nvim_get_mode().mode)
    t.assert_eq(0, #errors, vim.inspect(errors))
  end)
end

t:test("Visual-block preserves virtual columns when metadata outside its range changes", function()
  local data, state = fixture()
  support.applied(data:batch({
    { kind = "insert", key = "c", parent = { id = data:source():id("root") }, label = "gamma" },
  }))
  local c = data:source():id("c")
  local view = treeview.attach(state, { keymaps = false })
  t:defer(function()
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
    view:detach()
  end)
  local virtualedit = vim.api.nvim_get_option_value("virtualedit", { win = view.winnr, scope = "local" })
  t:defer(function()
    vim.api.nvim_set_option_value("virtualedit", virtualedit, { win = view.winnr, scope = "local" })
  end)
  vim.api.nvim_set_option_value("virtualedit", "block", { win = view.winnr, scope = "local" })
  t.wait_until(function()
    return view:frame() and view:frame():header().row_count == 3
  end, 5000)
  vim.api.nvim_win_set_cursor(view.winnr, { 1, 0 })
  vim.cmd.normal({ args = { vim.keycode("<C-v>20ljo10l") }, bang = true })
  t.assert_eq(21, vim.fn.virtcol("v"))
  t.assert_eq(11, vim.fn.virtcol("."))
  for index = 1, 2 do
    local anchor, cursor = vim.fn.getpos("v"), vim.fn.getpos(".")
    local anchor_column, cursor_column = vim.fn.virtcol("v"), vim.fn.virtcol(".")
    local label = "gamma " .. index
    support.applied(data:batch({ { kind = "update", id = c, label = label } }))
    t.wait_until(function()
      return vim.api.nvim_buf_get_lines(view.bufnr, 2, 3, true)[1] == "    " .. label
    end, 5000)
    t.assert_eq(vim.keycode("<C-v>"), vim.api.nvim_get_mode().mode)
    t.assert_eq(anchor_column, vim.fn.virtcol("v"), "metadata must preserve the block anchor's virtual column")
    t.assert_eq(cursor_column, vim.fn.virtcol("."), "metadata must preserve the block cursor's virtual column")
    t.assert_same(anchor, vim.fn.getpos("v"))
    t.assert_same(cursor, vim.fn.getpos("."))
    vim.cmd.normal({ args = { "o" }, bang = true })
  end
end)

t:run()
