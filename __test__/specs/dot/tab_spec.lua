local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

---@return dot.tab
---@return fun(): integer
local function setup()
  local dirty_count = 0

  t:patch_global("stl", require("stl"))
  t:patch_table(stl.nvim.win, "is_fixed", function()
    return false
  end)
  t:patch_table(stl.nvim.win, "is_float", function()
    return false
  end)
  t:patch_global("dot", {
    state = {
      status = {
        dirtier_tabline = {
          mark_dirty = function()
            dirty_count = dirty_count + 1
          end,
        },
      },
    },
    win = {
      is_sourcefile = function()
        return false
      end,
    },
  })

  return assert(loadfile("lua/dot/tab.lua"))(), function()
    return dirty_count
  end
end

---Opens a current tab that is closed when the case ends.
---@return integer
local function tabnew()
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  t:defer(function()
    if vim.api.nvim_tabpage_is_valid(tabnr) then
      vim.cmd.tabclose(vim.api.nvim_tabpage_get_number(tabnr))
    end
  end)
  return tabnr
end

t:test("equalize applies once through a normal window in the requested tab", function()
  local Tab = setup()
  local listed_tabnr = nil ---@type integer|nil
  local called_winnr = nil ---@type integer|nil
  local command = nil ---@type string|nil
  t:patch_table(stl.nvim.win, "is_float", function(winnr)
    return winnr == 11
  end)
  t:patch_table(vim.api, "nvim_tabpage_is_valid", function(tabnr)
    return tabnr == 42
  end)
  t:patch_table(vim.api, "nvim_tabpage_list_wins", function(tabnr)
    listed_tabnr = tabnr
    return { 11, 12, 13 }
  end)
  t:patch_table(vim.api, "nvim_win_call", function(winnr, callback)
    called_winnr = winnr
    return callback()
  end)
  t:patch_table(vim, "cmd", function(value)
    command = value
  end)

  Tab.equalize(42)

  t.assert_eq(42, listed_tabnr, "listed tab")
  t.assert_eq(12, called_winnr, "normal window context")
  t.assert_eq("wincmd =", command, "layout command")
end)

t:test("equalize skips invalid tabs and tabs without multiple normal windows", function()
  local Tab = setup()
  local calls = 0 ---@type integer
  t:patch_table(stl.nvim.win, "is_float", function(winnr)
    return winnr == 12
  end)
  t:patch_table(vim.api, "nvim_tabpage_is_valid", function(tabnr)
    return tabnr == 42
  end)
  t:patch_table(vim.api, "nvim_tabpage_list_wins", function()
    return { 11, 12 }
  end)
  t:patch_table(vim.api, "nvim_win_call", function()
    calls = calls + 1
  end)

  Tab.equalize(0)
  Tab.equalize(42)

  t.assert_eq(0, calls, "window calls")
end)

t:test("on_bufs_close marks the tabline dirty only when entries are removed", function()
  local Tab, get_dirty_count = setup()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local bufnr = t:buffer(nil, { listed = true })

  Tab.resolve(tabnr, true)
  Tab.add_buf(tabnr, bufnr, false)
  Tab.on_bufs_close(tabnr, { -1 })
  local dirty_after_noop = get_dirty_count()

  Tab.on_bufs_close(tabnr, { bufnr })
  local dirty_after_remove = get_dirty_count()
  local retained = Tab.has_buf(tabnr, bufnr)

  t.assert_eq(0, dirty_after_noop, "dirty count after no-op")
  t.assert_eq(1, dirty_after_remove, "dirty count after removal")
  t.assert_false(retained, "removed buffer metadata")
end)

t:test("on_bufs_close preserves references owned by other tabs", function()
  local Tab = setup()
  local tabnr_first = vim.api.nvim_get_current_tabpage()
  local bufnr = t:buffer(nil, { listed = true })

  Tab.resolve(tabnr_first, true)
  Tab.add_buf(tabnr_first, bufnr, false)

  local tabnr_second = tabnew()
  Tab.resolve(tabnr_second, true)
  Tab.add_buf(tabnr_second, bufnr, false)

  Tab.on_bufs_close(tabnr_first, { bufnr })
  local retained_first = Tab.has_buf(tabnr_first, bufnr)
  local retained_second = Tab.has_buf(tabnr_second, bufnr)
  local referenced_after_first_close = #Tab.retrieve_unreferenced_bufnrs({ bufnr }) == 0
  local valid_after_first_close = vim.api.nvim_buf_is_valid(bufnr)
  local listed_after_first_close = vim.api.nvim_get_option_value("buflisted", { buf = bufnr })

  Tab.on_bufs_close(tabnr_second, { bufnr })
  local bufnrs_unreferenced = Tab.retrieve_unreferenced_bufnrs({ bufnr })

  t.assert_false(retained_first, "first tab metadata")
  t.assert_true(retained_second, "second tab metadata")
  t.assert_true(referenced_after_first_close, "buffer remains referenced")
  t.assert_true(valid_after_first_close, "buffer remains valid")
  t.assert_true(listed_after_first_close, "buffer remains listed")
  t.assert_eq(1, #bufnrs_unreferenced, "unreferenced buffer count")
  t.assert_eq(bufnr, bufnrs_unreferenced[1], "unreferenced buffer")
end)

t:test("retrieve_unreferenced_bufnrs ignores invalid candidates", function()
  local Tab = setup()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local bufnr = t:buffer(nil, { listed = true })

  Tab.resolve(tabnr, true)
  vim.api.nvim_buf_delete(bufnr, { force = true })

  local ok, bufnrs = pcall(Tab.retrieve_unreferenced_bufnrs, { bufnr })

  t.assert_true(ok, "query result")
  t.assert_eq(0, #bufnrs, "unreferenced buffer count")
end)

t:test("on_buf_delete removes only the target from every tab and marks dirty once", function()
  local Tab, get_dirty_count = setup()
  local tabnr_first = vim.api.nvim_get_current_tabpage()
  local bufnr = t:buffer(nil, { listed = true })
  local bufnr_other = t:buffer(nil, { listed = true })

  Tab.resolve(tabnr_first, true)
  Tab.add_buf(tabnr_first, bufnr, false)
  Tab.add_buf(tabnr_first, bufnr_other, false)

  local tabnr_second = tabnew()
  Tab.resolve(tabnr_second, true)
  Tab.add_buf(tabnr_second, bufnr, false)
  Tab.add_buf(tabnr_second, bufnr_other, false)

  Tab.on_buf_delete(bufnr)
  Tab.on_buf_delete(bufnr)
  local retained_first = Tab.has_buf(tabnr_first, bufnr)
  local retained_second = Tab.has_buf(tabnr_second, bufnr)
  local retained_other_first = Tab.has_buf(tabnr_first, bufnr_other)
  local retained_other_second = Tab.has_buf(tabnr_second, bufnr_other)
  local dirty_count = get_dirty_count()

  t.assert_false(retained_first, "first tab metadata")
  t.assert_false(retained_second, "second tab metadata")
  t.assert_true(retained_other_first, "unrelated buffer in first tab")
  t.assert_true(retained_other_second, "unrelated buffer in second tab")
  t.assert_eq(1, dirty_count, "dirty count")
end)

t:test("TabClosed disposes metadata synchronously and defers buffer deletion", function()
  local Tab = setup()
  local tabnr = tabnew()
  local bufnr = t:buffer(nil, { listed = true })
  vim.api.nvim_win_set_buf(0, bufnr)
  local meta = Tab.resolve(tabnr, true)

  local bufdelete_count = 0
  local buffer_valid_during_event = false
  local metadata_disposed_during_event = false
  local bufdelete_autocmd = vim.api.nvim_create_autocmd("BufDelete", {
    callback = function(event)
      if event.buf == bufnr then
        bufdelete_count = bufdelete_count + 1
      end
    end,
  })
  t:defer(function()
    vim.api.nvim_del_autocmd(bufdelete_autocmd)
  end)
  local tabclosed_autocmd = vim.api.nvim_create_autocmd("TabClosed", {
    callback = function()
      Tab.on_close()
      buffer_valid_during_event = vim.api.nvim_buf_is_valid(bufnr)
      ---@diagnostic disable-next-line: need-check-nil
      metadata_disposed_during_event = meta.winnr_fixed:isdisposed()
        ---@diagnostic disable-next-line: need-check-nil
        and meta.winnr_float:isdisposed()
        ---@diagnostic disable-next-line: need-check-nil
        and meta.winnr_sourcefile:isdisposed()
    end,
  })
  t:defer(function()
    vim.api.nvim_del_autocmd(tabclosed_autocmd)
  end)

  vim.cmd.tabclose()
  t.wait_until(function()
    return not vim.api.nvim_buf_is_valid(bufnr)
  end, 5000, "the scheduled refresh must delete the closed tab's buffer")

  t.assert_true(buffer_valid_during_event, "buffer validity during TabClosed")
  t.assert_true(metadata_disposed_during_event, "metadata disposal during TabClosed")
  t.assert_eq(1, bufdelete_count, "BufDelete events")
end)

t:test("TabClosed deletes only buffers owned exclusively by closed tabs", function()
  local Tab = setup()
  local tabnr_first = vim.api.nvim_get_current_tabpage()
  local bufnr_shared = t:buffer(nil, { listed = true })

  Tab.resolve(tabnr_first, true)
  Tab.add_buf(tabnr_first, bufnr_shared, false)

  local tabnr_second = tabnew()
  local bufnr_owned = t:buffer(nil, { listed = true })
  vim.api.nvim_win_set_buf(0, bufnr_owned)
  Tab.resolve(tabnr_second, true)
  Tab.add_buf(tabnr_second, bufnr_shared, false)

  local bufnr_unrelated = t:buffer(nil, { listed = true })
  vim.api.nvim_buf_set_lines(bufnr_unrelated, 0, -1, false, { "unsaved" })

  local tabclosed_autocmd = vim.api.nvim_create_autocmd("TabClosed", {
    callback = function()
      Tab.on_close()
    end,
  })
  t:defer(function()
    vim.api.nvim_del_autocmd(tabclosed_autocmd)
  end)

  vim.cmd.tabclose()
  t.wait_until(function()
    return not vim.api.nvim_buf_is_valid(bufnr_owned)
  end, 5000, "the scheduled refresh must delete the buffer owned by the closed tab")
  local shared_valid = vim.api.nvim_buf_is_valid(bufnr_shared)
  local unrelated_valid = vim.api.nvim_buf_is_valid(bufnr_unrelated)
  local unrelated_listed = vim.api.nvim_get_option_value("buflisted", { buf = bufnr_unrelated })
  local unrelated_modified = vim.api.nvim_get_option_value("modified", { buf = bufnr_unrelated })

  t.assert_true(shared_valid, "buffer shared with a live tab")
  t.assert_true(unrelated_valid, "unrelated buffer validity")
  t.assert_true(unrelated_listed, "unrelated buffer listed option")
  t.assert_true(unrelated_modified, "unrelated buffer modified option")
end)

t:test("TabClosed preserves modified buffers owned exclusively by the closed tab", function()
  local Tab = setup()
  local tabnr = tabnew()
  local bufnr = t:buffer(nil, { listed = true })
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "unsaved" })
  Tab.resolve(tabnr, true)

  local schedule = bootstrap.with_schedule(t)
  local tabclosed_autocmd = vim.api.nvim_create_autocmd("TabClosed", {
    callback = function()
      Tab.on_close()
    end,
  })
  t:defer(function()
    vim.api.nvim_del_autocmd(tabclosed_autocmd)
  end)

  vim.cmd.tabclose()
  t.assert_true(#schedule.callbacks > 0, "scheduled refresh")
  schedule.drain()
  local valid = vim.api.nvim_buf_is_valid(bufnr)
  local modified = valid and vim.api.nvim_get_option_value("modified", { buf = bufnr }) or false
  local line = valid and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or nil

  t.assert_true(valid, "modified buffer remains valid")
  t.assert_true(modified, "modified flag is preserved")
  t.assert_eq("unsaved", line, "unsaved content is preserved")
end)

t:test("multiple TabClosed events coalesce into one refresh", function()
  local Tab = setup()
  local tabnr_first = vim.api.nvim_get_current_tabpage()
  Tab.resolve(tabnr_first, true)

  tabnew()
  local bufnr_second = t:buffer(nil, { listed = true })
  vim.api.nvim_win_set_buf(0, bufnr_second)
  Tab.resolve(vim.api.nvim_get_current_tabpage(), true)

  tabnew()
  local bufnr_third = t:buffer(nil, { listed = true })
  vim.api.nvim_win_set_buf(0, bufnr_third)
  Tab.resolve(vim.api.nvim_get_current_tabpage(), true)

  local schedule = bootstrap.with_schedule(t)
  local tabclosed_autocmd = vim.api.nvim_create_autocmd("TabClosed", {
    callback = function()
      Tab.on_close()
    end,
  })
  t:defer(function()
    vim.api.nvim_del_autocmd(tabclosed_autocmd)
  end)

  vim.api.nvim_set_current_tabpage(tabnr_first)
  vim.cmd.tabonly()
  local scheduled_count = #schedule.callbacks
  schedule.drain()
  local second_valid = vim.api.nvim_buf_is_valid(bufnr_second)
  local third_valid = vim.api.nvim_buf_is_valid(bufnr_third)

  t.assert_eq(1, scheduled_count, "scheduled refresh count")
  t.assert_false(second_valid, "second tab buffer validity")
  t.assert_false(third_valid, "third tab buffer validity")
end)

---A tab with a panel, then a left and a right source window.
---@return integer, integer, integer, integer
local function source_layout()
  local tabnr = tabnew()
  local left = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_buf(left, t:buffer(nil, { listed = true }))
  local right = vim.api.nvim_open_win(t:buffer(nil, { listed = true }), false, { split = "right", win = left })
  local panel = vim.api.nvim_open_win(t:buffer(), false, { split = "left", win = left })
  vim.w[left].sourcefile, vim.w[right].sourcefile = true, true
  return tabnr, left, right, panel
end

t:test("a rebuild keeps the source window the tab remembers while a panel is current", function()
  local Tab = setup()
  t:patch_table(dot.win, "is_sourcefile", function(winnr)
    return vim.w[winnr].sourcefile == true
  end)
  local tabnr, _, right, panel = source_layout()
  assert(Tab.resolve(tabnr, true)).winnr_sourcefile:next(right)
  vim.api.nvim_set_current_win(panel)

  Tab.refresh()

  t.assert_eq(right, Tab.retrieve_winnr_sourcefile(tabnr), "the remembered source window")
end)

t:test("a rebuild drops a remembered source window that closed", function()
  local Tab = setup()
  t:patch_table(dot.win, "is_sourcefile", function(winnr)
    return vim.w[winnr].sourcefile == true
  end)
  local tabnr, left, right, panel = source_layout()
  assert(Tab.resolve(tabnr, true)).winnr_sourcefile:next(right)
  vim.api.nvim_set_current_win(panel)
  vim.api.nvim_win_close(right, true)

  Tab.refresh()

  t.assert_eq(left, Tab.retrieve_winnr_sourcefile(tabnr), "a source window still open")
end)

t:run()
