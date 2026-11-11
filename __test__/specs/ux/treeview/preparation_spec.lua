local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new()
bootstrap.with_native(t)
local support = require("__test__.support.treeview")
local fixture = support.fixture

for _, failure in ipairs({ "throw", "reject", "invalid result" }) do
  t:test(
    "decoration preparation settles after " .. failure .. " and an explicit refresh retries the same frame",
    function()
      local _, state = fixture()
      local calls, errors, failing = 0, {}, false
      local view = support.attach(t, state, {
        keymaps = false,
        prepare_frame = function()
          calls = calls + 1
          if failing then
            if failure == "throw" then
              error("injected preparation failure", 0)
            elseif failure == "reject" then
              return stl.c.Future.reject("injected preparation failure")
            end
            return stl.c.Future.resolve(nil)
          end
          return stl.c.Future.resolve(function() end)
        end,
        on_error = function(error)
          errors[#errors + 1] = error
        end,
      })
      t.wait_until(function()
        return view:frame() and not view:status().preparing
      end, 5000)
      local frame, tick = view:frame():id(), vim.api.nvim_buf_get_changedtick(view.bufnr)
      failing = true
      for attempt = 1, 2 do
        view:refresh_decorations()
        t.wait_until(function()
          return #errors == attempt
        end, 5000)
        t.assert_false(view:status().preparing, "a failed request must release its pending state")
        t.assert_true(view:status().error ~= nil)
        t.assert_eq(frame, view:frame():id())
        t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr))
        local completed = calls
        view:_poll()
        vim.cmd.redraw()
        t.await(state:inspect_selection())
        view:_poll()
        t.assert_eq(completed, calls, "ordinary polling and redraw must not retry a failed preparation")
      end
      failing = false
      view:refresh_decorations()
      t.wait_until(function()
        return not view:status().preparing and view:status().error == nil
      end, 5000)
      t.assert_eq(frame, view:frame():id())
      t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr))
      t.assert_eq("Swap", view:status().last_plan.mode)
    end
  )
end

t:test("a superseded preparation rejection preserves the newer decoration request", function()
  local _, state = fixture()
  local pending, errors, delayed, commits = {}, {}, false, 0
  local view = support.attach(t, state, {
    keymaps = false,
    prepare_frame = function()
      if not delayed then
        return stl.c.Future.resolve(function() end)
      end
      return stl.c.Future.new(function(resolve, reject)
        pending[#pending + 1] = { resolve = resolve, reject = reject }
      end)
    end,
    on_error = function(error)
      errors[#errors + 1] = error
    end,
  })
  t.wait_until(function()
    return view:frame() and not view:status().preparing
  end, 5000)
  delayed = true
  view:refresh_decorations()
  t.wait_until(function()
    return #pending == 1
  end, 5000)
  view:refresh_decorations()
  pending[1].reject("superseded preparation failed")
  t.wait_until(function()
    return #pending == 2
  end, 5000)
  t.assert_true(view:status().preparing)
  t.assert_nil(view:status().error)
  t.assert_eq(0, #errors)
  pending[2].resolve(function()
    commits = commits + 1
  end)
  t.wait_until(function()
    return not view:status().preparing
  end, 5000)
  t.assert_eq(1, commits)
end)

t:test("a pending cursor publication cannot reuse text after a branch suffix changes", function()
  local data, state = fixture()
  support.applied(state:set_display({ mode = "list", list_depth = 0, branch_suffix = "/" }))
  local Future = require("stl.c.future")
  local hold, complete = false, nil
  local errors = {}
  local view = support.attach(t, state, {
    keymaps = false,
    prepare_frame = function()
      if hold then
        return Future.new(function(resolve)
          complete = resolve
        end)
      end
      return Future.resolve(function()
        return false
      end)
    end,
    on_error = function(error)
      errors[#errors + 1] = error
    end,
  })
  t.wait_until(function()
    return view:frame() ~= nil and not view:status().preparing
  end, 5000)
  for _, can_expand in ipairs({ true, false }) do
    hold, complete = true, nil
    support.applied(view:set_cursor(can_expand and 2 or 1))
    t.wait_until(function()
      return complete ~= nil
    end, 5000)
    support.applied(data:batch({ { kind = "update", node = "a", can_expand = can_expand } }))
    t.wait_until(function()
      return state:snapshot():header().data_revision == data:source():revision()
    end, 5000)
    hold = false
    complete(function()
      return false
    end)
    t.wait_until(function()
      return view:frame():header().data_revision == data:source():revision() and not view:status().preparing
    end, 5000)
    local label = can_expand and "alpha/" or "alpha"
    t.assert_eq(label, view:frame():rows(1, 1).labels[1])
    t.assert_eq("  " .. label, vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, false)[1])
  end
  t.assert_eq(0, #errors)
end)

t:test("retargeting a plan re-prepares row-dependent features after selection changes", function()
  local _, state, a = fixture()
  local pending, committed, delayed = {}, {}, false
  local view = support.attach(t, state, {
    keymaps = false,
    prepare_frame = function(_, _, _, _, rows)
      local selected = rows.marked[1]
      if not delayed then
        return stl.c.Future.resolve(function() end)
      end
      return stl.c.Future.new(function(resolve)
        pending[#pending + 1] = function()
          resolve(function(frame)
            committed[#committed + 1] = { selected, frame:rows(1, 1).marked[1] }
          end)
        end
      end)
    end,
  })
  t.wait_until(function()
    return view:frame() ~= nil
  end, 5000)
  delayed = true
  view:refresh_decorations()
  t.wait_until(function()
    return #pending == 1
  end, 5000)
  local layout = view:frame():header().layout_revision
  support.applied(state:select_node({ a }, false))
  t.assert_eq(layout, state:snapshot():header().layout_revision)
  pending[1]()
  t.wait_until(function()
    return #pending == 2 or #committed ~= 0
  end, 5000)
  t.assert_eq(0, #committed, "old row columns cannot be relabeled as a newer frame")
  pending[2]()
  t.wait_until(function()
    return not view:status().preparing
  end, 5000)
  t.assert_true(committed[1][1])
  t.assert_true(committed[1][2])
end)

for _, failure in ipairs({ "throw", "invalid future" }) do
  t:test("retargeted preparation records the current frame after " .. failure, function()
    local _, state, a = fixture()
    local pending, calls, errors, mode = nil, 0, {}, "ready"
    local view = support.attach(t, state, {
      keymaps = false,
      prepare_frame = function()
        calls = calls + 1
        if mode == "pending" then
          return stl.c.Future.new(function(resolve)
            pending = resolve
          end)
        elseif mode == "failed" then
          if failure == "throw" then
            error("retargeted preparation failed", 0)
          end
          return nil
        end
        return stl.c.Future.resolve(function() end)
      end,
      on_error = function(error)
        errors[#errors + 1] = error
      end,
    })
    t.wait_until(function()
      return view:frame() and not view:status().preparing
    end, 5000)
    local original = view:frame():id()
    mode = "pending"
    view:refresh_decorations()
    t.wait_until(function()
      return pending ~= nil
    end, 5000)
    local selected = support.applied(state:select_node({ a }, false))
    t.wait_until(function()
      return state:native():applicable(state:snapshot(), selected.revisions.commit)
    end, 5000)
    local target = state:snapshot():id()
    t.assert_true(target ~= original)
    mode = "failed"
    pending(function()
      error("the old frame cannot commit")
    end)
    t.wait_until(function()
      return #errors > 0
    end, 5000)
    t.assert_false(view:status().preparing)
    local failed_calls = calls
    view:_poll()
    vim.cmd.redraw()
    t.await(state:inspect_selection())
    view:_poll()
    t.assert_eq(failed_calls, calls, "retargeting must not make the failed frame eligible for ordinary retry")
    t.assert_eq(1, #errors)
    t.assert_eq(original, view:frame():id())
    mode = "ready"
    view:refresh_decorations()
    t.wait_until(function()
      return not view:status().preparing and view:status().error == nil
    end, 5000)
    t.assert_eq(target, view:frame():id())
    t.assert_true(view:frame():rows(1, 1).marked[1])
  end)
end

t:run()
