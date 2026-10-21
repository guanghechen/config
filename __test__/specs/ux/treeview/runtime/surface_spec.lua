local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new()
bootstrap.with_native(t)
local treeview = require("ux.treeview")
local support = require("__test__.support.treeview")
local fixture = support.fixture

t:test("an empty scratch buffer transfers to the view without entering another buffer", function()
  local _, state = fixture()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "custom_tree", { buf = bufnr })
  vim.api.nvim_win_set_buf(0, bufnr)
  local enters = 0
  local group = vim.api.nvim_create_augroup("TreeviewBufferTransferTest", { clear = true })
  t:defer(function()
    vim.api.nvim_del_augroup_by_id(group)
  end)
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      enters = enters + 1
    end,
  })
  local view = treeview.attach(state, { bufnr = bufnr, keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  t.assert_eq(bufnr, view.bufnr)
  t.assert_eq("custom_tree", vim.api.nvim_get_option_value("filetype", { buf = bufnr }))
  t.assert_eq(0, enters)
  view:detach()
  t.assert_false(vim.api.nvim_buf_is_valid(bufnr))
end)

t:test("buffer transfer rejects existing contents before claiming the surface", function()
  local _, state = fixture()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "keep this content" })
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  local ok = pcall(treeview.attach, state, { bufnr = bufnr, keymaps = false })
  t.assert_false(ok)
  t.assert_eq("keep this content", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
end)

t:test("an empty buffer already owned by another view cannot be transferred", function()
  local data = treeview.new_data()
  local state = t.await(data:create_state({ kind = "forest", nodes = {} }))
  local view = treeview.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() and not view._busy
  end, 5000)
  t.assert_eq(0, view:frame():header().row_count)
  t.assert_false(pcall(treeview.attach, state, { bufnr = view.bufnr, keymaps = false }))
  t.assert_true(view:_valid())
  t.assert_false(pcall(treeview.attach, state, { bufnr = 0, keymaps = false }))
end)

t:test("buffer unload revokes pending frame work before deferred surface cleanup", function()
  local data, state, _, b = fixture()
  local reject, preparing, closed_on_unload
  local errors, frames = {}, 0
  local pending = require("stl.c.future").new(function(_, failed)
    reject = failed
  end)
  local view = treeview.attach(state, {
    keymaps = false,
    prepare_frame = function()
      preparing = true
      return pending
    end,
    on_error = function(error)
      errors[#errors + 1] = error
    end,
    on_frame = function()
      frames = frames + 1
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return preparing == true
  end, 5000)
  vim.api.nvim_create_autocmd("BufUnload", {
    buf = view.bufnr,
    once = true,
    callback = function()
      closed_on_unload = view:status().closed
      -- Consumer preparation can finish before the scheduled detach gets a turn.
      reject("consumer stopped preparing an unloaded surface")
    end,
  })
  vim.api.nvim_buf_delete(view.bufnr, { force = true, unload = true })
  t.assert_true(closed_on_unload, "an unloading buffer must already be closed to frame callbacks")
  t.assert_eq(0, #errors, "late preparation reported an error after unload: " .. vim.inspect(errors))
  t.assert_eq(0, frames)
  t.wait_until(function()
    return data._views[view] == nil
  end, 5000)
  view:detach()
  view:detach()
  support.applied(state:dispatch({ kind = "set_cursor", node = b }, { frame = state:snapshot() }))
  local replacement = treeview.attach(state, { keymaps = false })
  t:defer(function()
    replacement:detach()
  end)
  t.wait_until(function()
    return replacement:frame() ~= nil and not replacement:status().preparing
  end, 5000)
  t.assert_eq(b, replacement:frame():header().cursor)
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
  t.assert_same({ "    alpha", "    beta" }, vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, true))
  local tick = vim.api.nvim_buf_get_changedtick(view.bufnr)
  support.applied(state:select_node({ a }, false))
  t.wait_until(function()
    return view:frame():rows(1, 1).marked[1]
  end, 5000)
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr), "selection must not write body text")
  support.applied(data:batch({ { kind = "update", id = a, label = "renamed" } }))
  t.wait_until(function()
    return vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1] == "    renamed"
  end, 5000)
  t.assert_eq("Delta", view:status().last_plan.mode)
  t.assert_eq(1, view:status().last_plan.written_rows)
  support.applied(state:set_root({ kind = "forest", nodes = {} }))
  t.wait_until(function()
    return view:status().frame.row_count == 0
  end, 5000)
  t.assert_eq(1, vim.api.nvim_buf_line_count(view.bufnr))
  t.assert_nil(view:frame():node_at(1))
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:test("partial buffer failure disables input and resynchronizes the complete frame once", function()
  local data = treeview.new_data()
  local records = { { key = "root", label = "root", can_expand = true } }
  for index = 1, 12 do
    records[#records + 1] = { key = "n" .. index, parent = "root", label = "node" .. index }
  end
  support.applied(data:import(records))
  local state = t.await(data:create_state({ kind = "children_of", node = data:source():id("root") }))
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
  support.applied(data:batch({
    { kind = "update", node = "n1", label = "first changed" },
    { kind = "update", node = "n12", label = "last changed" },
  }))
  t.wait_until(function()
    return writes >= 3 and not view:status().desynced
  end, 5000)
  t.assert_eq("Rejected", blocked.kind)
  t.assert_eq("Reset", view:status().last_plan.mode)
  t.assert_eq("    first changed", vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1])
  t.assert_eq("    last changed", vim.api.nvim_buf_get_lines(view.bufnr, 11, 12, true)[1])
  t.assert_true(#errors >= 1)
  t.assert_true(t.await(state:inspect_selection()).summary.is_empty)
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

t:test("attachment installs preparation before the first frame and decoration refresh rejects stale work", function()
  local _, state = fixture()
  local pending, commits = {}, 0
  local view = treeview.attach(state, {
    keymaps = false,
    on_attach = function(current)
      t.assert_nil(current:frame())
      current._options.prepare_frame = function(_, frame, first, last, rows)
        t.assert_eq(last - first, #rows.ids)
        t.assert_eq(frame:node_at(first + 1), rows.ids[1])
        return require("stl.c.future").new(function(resolve)
          pending[#pending + 1] = resolve
        end)
      end
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return #pending == 1
  end, 5000)
  view:refresh_decorations()
  t.assert_true(view:status().preparing)
  pending[1](function()
    commits = commits + 100
  end)
  t.wait_until(function()
    return #pending == 2
  end, 5000)
  t.assert_eq(0, commits)
  pending[2](function()
    commits = commits + 1
  end)
  t.wait_until(function()
    return view:frame() ~= nil and not view:status().preparing
  end, 5000)
  local frame = view:frame():id()
  local changedtick = vim.api.nvim_buf_get_changedtick(view.bufnr)
  view:refresh_decorations()
  t.wait_until(function()
    return #pending == 3
  end, 5000)
  pending[3](function()
    commits = commits + 1
  end)
  t.wait_until(function()
    return not view:status().preparing
  end, 5000)
  t.assert_eq(2, commits)
  t.assert_eq(frame, view:frame():id())
  t.assert_eq(changedtick, vim.api.nvim_buf_get_changedtick(view.bufnr))
  t.assert_eq("Swap", view:status().last_plan.mode)
  view:refresh_decorations()
  t.wait_until(function()
    return #pending == 4
  end, 5000)
  view:detach()
  pending[4](function()
    commits = commits + 100
  end)
  t.assert_eq(2, commits, "a detached view cannot publish late viewport work")
end)

t:test("failed attachment releases the view and restores its original buffer", function()
  local data, state = fixture()
  local bufnr = vim.api.nvim_get_current_buf()
  local attached
  local ok, failure = pcall(treeview.attach, state, {
    keymaps = false,
    on_attach = function(view)
      attached = view
      error("attachment rejected", 0)
    end,
  })
  t.assert_false(ok)
  t.assert_true(tostring(failure):find("attachment rejected", 1, true) ~= nil)
  t.assert_true(attached:status().closed)
  t.assert_eq(nil, next(data._views))
  t.assert_eq(bufnr, vim.api.nvim_get_current_buf())
end)

t:run()
