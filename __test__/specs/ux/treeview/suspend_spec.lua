local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
bootstrap.with_native(t)
local Future = require("stl.c.future")
local treeview = require("ux.treeview")
local support = require("__test__.support.treeview")
local decorations = require("ux.treeview.decorations")

local fixture = support.fixture

---@return integer
---@return integer
local function window()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 0, col = 0, width = 40, height = 6 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return winnr, bufnr
end

t:test("suspension retains ownership, rebinds a window and restores each window's options", function()
  local data, state = fixture()
  local first, original = window()
  vim.api.nvim_set_option_value("wrap", true, { win = first })
  local view = treeview.attach(state, { winnr = first, keymaps = false })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() and not view:status().preparing
  end, 5000)
  support.await(view:set_cursor(2))
  t.wait_until(function()
    return view:frame():header().cursor_row == 2 and not view:status().preparing
  end, 5000)
  local frame, bufnr = view:frame(), view.bufnr
  local writes, set_lines = 0, vim.api.nvim_buf_set_lines
  t:patch_table(vim.api, "nvim_buf_set_lines", function(target, ...)
    if target == bufnr then
      writes = writes + 1
    end
    return set_lines(target, ...)
  end)
  view:suspend()
  t.assert_true(view:is_suspended())
  t.assert_nil(data._views[view])
  t.assert_true(decorations.attached(bufnr), "hidden buffers remain exclusively owned")
  t.assert_eq(original, vim.api.nvim_win_get_buf(first))
  t.assert_true(vim.api.nvim_get_option_value("wrap", { win = first }))
  t.assert_eq("Rejected", view:set_cursor(1):get_result().kind)
  vim.api.nvim_win_close(first, true)
  t.assert_false(view:status().closed, "closing the released window must not destroy the retained view")

  local second, placeholder = window()
  vim.api.nvim_set_option_value("number", true, { win = second })
  view:resume(second)
  t.wait_until(function()
    return not view:status().preparing
  end, 5000)
  t.assert_true(data._views[view])
  t.assert_eq(bufnr, vim.api.nvim_win_get_buf(second))
  t.assert_eq(2, vim.api.nvim_win_get_cursor(second)[1])
  t.assert_eq(frame:id(), view:frame():id())
  t.assert_eq(0, writes)
  t.assert_false(vim.api.nvim_get_option_value("number", { win = second }))
  view:detach()
  t.assert_eq(placeholder, vim.api.nvim_win_get_buf(second))
  t.assert_true(vim.api.nvim_get_option_value("number", { win = second }))
  t.assert_false(vim.api.nvim_buf_is_valid(bufnr))
  t.assert_false(decorations.attached(bufnr))
end)

t:test("a preparation reply from the released window cannot publish into the resumed view", function()
  local data, state = fixture()
  local first = window()
  local errors, held, stale_commit = {}, nil, false
  local view = treeview.attach(state, {
    winnr = first,
    keymaps = false,
    on_error = function(error)
      errors[#errors + 1] = error
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() and not view:status().preparing
  end, 5000)
  view._options.prepare_frame = function()
    if not held then
      return Future.new(function(resolve)
        held = resolve
      end)
    end
    return Future.resolve(function() end)
  end
  support.await(data:batch({ { kind = "update", node = "a", label = "intermediate" } }))
  t.wait_until(function()
    return held ~= nil
  end, 5000)
  view:suspend()
  support.await(data:batch({ { kind = "update", node = "a", label = "latest" } }))
  local second = window()
  view:resume(second)
  held(function()
    stale_commit = true
  end)
  t.wait_until(function()
    local frame = view:frame()
    return frame and frame:node(data:source():id("a")).label == "latest" and not view:status().preparing
  end, 5000)
  t.assert_false(stale_commit)
  t.assert_eq(0, #errors, vim.inspect(errors))
  t.assert_true(vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1]:find("latest", 1, true) ~= nil)
end)

for _, binding in ipairs({ 1, 2 }) do
  t:test("closing during window binding " .. binding .. " does not reactivate the view", function()
    local data, state = fixture()
    local count = 0
    local view = treeview.attach(state, {
      winnr = window(),
      keymaps = false,
      on_attach = function(current)
        count = count + 1
        if count == binding then
          current:detach()
        end
      end,
    })
    t:defer(function()
      view:detach()
    end)
    if binding == 2 then
      t.wait_until(function()
        return view:frame() and not view:status().preparing
      end, 5000)
      view:suspend()
      view:resume(window())
    end
    t.assert_true(view:status().closed)
    t.assert_nil(data._views[view])
    t.assert_false(vim.api.nvim_buf_is_valid(view.bufnr))
  end)
end

t:run()
