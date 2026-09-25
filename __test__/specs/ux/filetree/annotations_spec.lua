---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.filetree.annotations" ---@type string

local fixture = require("__test__.support.filetree").new("ux.filetree.annotations")
local t, filetree = fixture.t, fixture.filetree
local await, write, directory = fixture.await, fixture.write, fixture.directory

t:test("diagnostics decorate a stable frame and clear by namespace without editing buffer lines", function()
  local path = directory()
  write(path .. "/a")
  write(path .. "/b")
  local data = await(filetree.open(path))
  local state = await(data:create_state(nil, { mode = "list" }))
  local view = filetree.attach(state, { keymaps = false })
  t:defer(function()
    view:detach()
  end)
  local stable
  t.wait_until(function()
    local frame = view:frame()
    local ready = frame
      and frame:header().row_count == 2
      and state._native:applicable(frame)
      and not data._native:is_busy()
      and data._native:stats().queue_depth == 0
    if ready then
      stable = stable or vim.uv.hrtime()
    else
      stable = nil
    end
    return stable and vim.uv.hrtime() - stable >= 50000000
  end, 10000)
  local frame = view:frame()
  local lines = vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, true)
  local tick = vim.api.nvim_buf_get_changedtick(view.bufnr)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, path .. "/a")
  local namespace = vim.api.nvim_create_namespace("filetree-test-diagnostics")
  t:defer(function()
    vim.diagnostic.reset(namespace)
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.diagnostic.set(namespace, bufnr, { { lnum = 0, col = 0, message = "error", severity = 1 } })
  await(data:sync_diagnostics(namespace, bufnr))
  local rows = await(data:annotations(frame, 1, 2))
  t.assert_true(vim.deep_equal({ 1, 0, 0, 0 }, rows.rows[1].diagnostics))
  t.assert_eq(1, await(data:next_annotation(frame, 2, "error", true)))
  vim.cmd.redraw()
  t.wait_until(function()
    return view._filetree_annotations and view._filetree_annotations.rows[1].diagnostics[1] == 1
  end, 10000)
  vim.diagnostic.reset(namespace, bufnr)
  await(data:sync_diagnostics(namespace, bufnr))
  t.wait_until(function()
    return view._filetree_annotations and view._filetree_annotations.rows[1].diagnostics[1] == 0
  end, 10000)
  t.assert_eq(0, await(data:next_annotation(frame, 0, "diagnostic", true)))
  t.assert_eq(frame:id(), view:frame():id())
  t.assert_true(vim.deep_equal(lines, vim.api.nvim_buf_get_lines(view.bufnr, 0, -1, true)))
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(view.bufnr))
end)

for _, outcome in ipairs({ "success", "Stale" }) do
  t:test("late " .. outcome .. " from an old viewport cannot overwrite a prepared publication", function()
    local header = { data_revision = "data-1", layout_revision = "layout-1" }
    local source = {}
    local frame = {
      id = function()
        return "frame-1"
      end,
      header = function()
        return header
      end,
      source = function()
        return source
      end,
    }
    local rows = {}
    for index = 1, 10 do
      rows[index] = { diagnostics = { 1, 0, 0, 0 }, git = 0 }
    end
    local cached = { frame = "frame-1", revision = "1", first = 1, rows = rows }
    local bufnr = vim.api.nvim_create_buf(false, true)
    t:defer(function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    local view = {
      bufnr = bufnr,
      _frame = frame,
      _header = header,
      _options = {},
      _decorations = { frame = "frame-1", first = 5, last = 15 },
      _filetree_annotations = cached,
      _filetree_annotation_data = "data-1",
      _filetree_annotation_layout = "layout-1",
      _filetree_annotation_source = source,
      _redraw = function() end,
      detach = function(self)
        self._closed = true
      end,
    }
    local annotations = require("ux.filetree.annotations")
    annotations.attach(view)
    t:defer(function()
      view:detach()
    end)
    local calls, ready = 0, false
    local reply = outcome == "success" and { frame = "frame-1", revision = "1", first = 6, rows = rows }
      or { kind = "Rejected", error = { code = outcome } }
    local owner = { _views = { [view] = true } }
    local native = {
      annotation_revision = function()
        return "1"
      end,
      annotations = function(_, _, first, last)
        calls = calls + 1
        t.assert_eq(6, first)
        t.assert_eq(15, last)
        return {
          poll = function()
            return ready, reply
          end,
        }
      end,
    }
    t.assert_true(annotations.poll(owner, native))
    view._decorations = { frame = "frame-1", first = 0, last = 10 }
    local commit = await(annotations.prepare(view, native, frame, 0, 10))
    commit(frame)
    local key = view._filetree_annotation_key
    ready = true
    t.wait_until(function()
      return view._filetree_pending == nil
    end, 5000)
    t.assert_true(view._filetree_annotations == cached, "the current publication keeps its complete viewport")
    t.assert_eq(key, view._filetree_annotation_key, "an old request cannot invalidate the current key")
    t.assert_false(annotations.poll(owner, native))
    t.assert_eq(1, calls, "the current viewport is already complete")
  end)
end

t:run()
