---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/dot/tab.lua

local harness = require("__test__.harness")

local t = harness.new("dot.tab")

local Observable = {}
Observable.__index = Observable

---@param value                          any
---@return table
function Observable.from_value(value)
  return setmetatable({ value = value, disposed = false }, Observable)
end

---@return any
function Observable:snapshot()
  return self.value
end

---@param value                          any
---@return nil
function Observable:next(value)
  self.value = value
end

---@return nil
function Observable:dispose()
  self.disposed = true
end

---@return dot.tab
---@return fun(): integer
local function setup()
  local dirty_count = 0

  t:patch_global("stl", {
    c = { Observable = Observable },
    e = { TabTypeEnum = { NORMAL = 0 } },
    nvim = {
      win = {
        is_fixed = function()
          return false
        end,
        is_float = function()
          return false
        end,
      },
    },
  })
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

t:test("on_bufs_close marks the tabline dirty only when entries are removed", function()
  local Tab, get_dirty_count = setup()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local bufnr = vim.api.nvim_create_buf(true, false)

  Tab.resolve(tabnr, true)
  Tab.add_buf(tabnr, bufnr, false)
  Tab.on_bufs_close(tabnr, { -1 })
  local dirty_after_noop = get_dirty_count()

  Tab.on_bufs_close(tabnr, { bufnr })
  local dirty_after_remove = get_dirty_count()
  local retained = Tab.has_buf(tabnr, bufnr)

  vim.api.nvim_buf_delete(bufnr, { force = true })

  t.assert_eq(0, dirty_after_noop, "dirty count after no-op")
  t.assert_eq(1, dirty_after_remove, "dirty count after removal")
  t.assert_false(retained, "removed buffer metadata")
end)

t:test("on_bufs_close preserves references owned by other tabs", function()
  local Tab = setup()
  local tabnr_first = vim.api.nvim_get_current_tabpage()
  local bufnr = vim.api.nvim_create_buf(true, false)

  Tab.resolve(tabnr_first, true)
  Tab.add_buf(tabnr_first, bufnr, false)

  vim.cmd.tabnew()
  local tabnr_second = vim.api.nvim_get_current_tabpage()
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

  vim.cmd.tabclose()
  vim.api.nvim_buf_delete(bufnr, { force = true })

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
  local bufnr = vim.api.nvim_create_buf(true, false)

  Tab.resolve(tabnr, true)
  vim.api.nvim_buf_delete(bufnr, { force = true })

  local ok, bufnrs = pcall(Tab.retrieve_unreferenced_bufnrs, { bufnr })

  t.assert_true(ok, "query result")
  t.assert_eq(0, #bufnrs, "unreferenced buffer count")
end)

t:test("on_buf_delete removes only the target from every tab and marks dirty once", function()
  local Tab, get_dirty_count = setup()
  local tabnr_first = vim.api.nvim_get_current_tabpage()
  local bufnr = vim.api.nvim_create_buf(true, false)
  local bufnr_other = vim.api.nvim_create_buf(true, false)

  Tab.resolve(tabnr_first, true)
  Tab.add_buf(tabnr_first, bufnr, false)
  Tab.add_buf(tabnr_first, bufnr_other, false)

  vim.cmd.tabnew()
  local tabnr_second = vim.api.nvim_get_current_tabpage()
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

  vim.cmd.tabclose()
  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(bufnr_other, { force = true })

  t.assert_false(retained_first, "first tab metadata")
  t.assert_false(retained_second, "second tab metadata")
  t.assert_true(retained_other_first, "unrelated buffer in first tab")
  t.assert_true(retained_other_second, "unrelated buffer in second tab")
  t.assert_eq(1, dirty_count, "dirty count")
end)

t:test("TabClosed disposes metadata synchronously and defers buffer deletion", function()
  local Tab = setup()
  vim.cmd.tabnew()

  local tabnr = vim.api.nvim_get_current_tabpage()
  local bufnr = vim.api.nvim_create_buf(true, false)
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
  local tabclosed_autocmd = vim.api.nvim_create_autocmd("TabClosed", {
    callback = function()
      Tab.on_close()
      buffer_valid_during_event = vim.api.nvim_buf_is_valid(bufnr)
      metadata_disposed_during_event = meta.winnr_fixed.disposed
        and meta.winnr_float.disposed
        and meta.winnr_sourcefile.disposed
    end,
  })

  vim.cmd.tabclose()
  local refresh_completed = vim.wait(1000, function()
    return not vim.api.nvim_buf_is_valid(bufnr)
  end, 10)
  local buffer_valid_after_refresh = vim.api.nvim_buf_is_valid(bufnr)
  local observed_bufdelete_count = bufdelete_count

  pcall(vim.api.nvim_del_autocmd, tabclosed_autocmd)
  pcall(vim.api.nvim_del_autocmd, bufdelete_autocmd)
  if buffer_valid_after_refresh then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  t.assert_true(buffer_valid_during_event, "buffer validity during TabClosed")
  t.assert_true(metadata_disposed_during_event, "metadata disposal during TabClosed")
  t.assert_true(refresh_completed, "scheduled refresh")
  t.assert_false(buffer_valid_after_refresh, "buffer validity after refresh")
  t.assert_eq(1, observed_bufdelete_count, "BufDelete events")
end)

t:test("TabClosed deletes only buffers owned exclusively by closed tabs", function()
  local Tab = setup()
  local tabnr_first = vim.api.nvim_get_current_tabpage()
  local bufnr_shared = vim.api.nvim_create_buf(true, false)

  Tab.resolve(tabnr_first, true)
  Tab.add_buf(tabnr_first, bufnr_shared, false)

  vim.cmd.tabnew()
  local tabnr_second = vim.api.nvim_get_current_tabpage()
  local bufnr_owned = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, bufnr_owned)
  Tab.resolve(tabnr_second, true)
  Tab.add_buf(tabnr_second, bufnr_shared, false)

  local bufnr_unrelated = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(bufnr_unrelated, 0, -1, false, { "unsaved" })

  local tabclosed_autocmd = vim.api.nvim_create_autocmd("TabClosed", {
    callback = function()
      Tab.on_close()
    end,
  })

  vim.cmd.tabclose()
  local refresh_completed = vim.wait(1000, function()
    return not vim.api.nvim_buf_is_valid(bufnr_owned)
  end, 10)
  local shared_valid = vim.api.nvim_buf_is_valid(bufnr_shared)
  local unrelated_valid = vim.api.nvim_buf_is_valid(bufnr_unrelated)
  local unrelated_listed = vim.api.nvim_get_option_value("buflisted", { buf = bufnr_unrelated })
  local unrelated_modified = vim.api.nvim_get_option_value("modified", { buf = bufnr_unrelated })

  pcall(vim.api.nvim_del_autocmd, tabclosed_autocmd)
  if vim.api.nvim_buf_is_valid(bufnr_owned) then
    vim.api.nvim_buf_delete(bufnr_owned, { force = true })
  end
  vim.api.nvim_buf_delete(bufnr_shared, { force = true })
  vim.api.nvim_buf_delete(bufnr_unrelated, { force = true })

  t.assert_true(refresh_completed, "scheduled refresh")
  t.assert_true(shared_valid, "buffer shared with a live tab")
  t.assert_true(unrelated_valid, "unrelated buffer validity")
  t.assert_true(unrelated_listed, "unrelated buffer listed option")
  t.assert_true(unrelated_modified, "unrelated buffer modified option")
end)

t:test("TabClosed preserves modified buffers owned exclusively by the closed tab", function()
  local Tab = setup()
  vim.cmd.tabnew()

  local tabnr = vim.api.nvim_get_current_tabpage()
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "unsaved" })
  Tab.resolve(tabnr, true)

  local scheduled = nil ---@type fun()|nil
  t:patch_table(vim, "schedule", function(callback)
    scheduled = callback
  end)
  local tabclosed_autocmd = vim.api.nvim_create_autocmd("TabClosed", {
    callback = function()
      Tab.on_close()
    end,
  })

  vim.cmd.tabclose()
  assert(scheduled)()
  local valid = vim.api.nvim_buf_is_valid(bufnr)
  local modified = valid and vim.api.nvim_get_option_value("modified", { buf = bufnr }) or false
  local line = valid and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or nil

  pcall(vim.api.nvim_del_autocmd, tabclosed_autocmd)
  if valid then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  t.assert_true(valid, "modified buffer remains valid")
  t.assert_true(modified, "modified flag is preserved")
  t.assert_eq("unsaved", line, "unsaved content is preserved")
end)

t:test("multiple TabClosed events coalesce into one refresh", function()
  local Tab = setup()
  local tabnr_first = vim.api.nvim_get_current_tabpage()
  Tab.resolve(tabnr_first, true)

  vim.cmd.tabnew()
  local bufnr_second = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, bufnr_second)
  Tab.resolve(vim.api.nvim_get_current_tabpage(), true)

  vim.cmd.tabnew()
  local bufnr_third = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, bufnr_third)
  Tab.resolve(vim.api.nvim_get_current_tabpage(), true)

  local scheduled = {} ---@type fun()[]
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)
  local tabclosed_autocmd = vim.api.nvim_create_autocmd("TabClosed", {
    callback = function()
      Tab.on_close()
    end,
  })

  vim.api.nvim_set_current_tabpage(tabnr_first)
  vim.cmd.tabonly()
  local scheduled_count = #scheduled
  scheduled[1]()
  local second_valid = vim.api.nvim_buf_is_valid(bufnr_second)
  local third_valid = vim.api.nvim_buf_is_valid(bufnr_third)

  pcall(vim.api.nvim_del_autocmd, tabclosed_autocmd)
  if second_valid then
    vim.api.nvim_buf_delete(bufnr_second, { force = true })
  end
  if third_valid then
    vim.api.nvim_buf_delete(bufnr_third, { force = true })
  end

  t.assert_eq(1, scheduled_count, "scheduled refresh count")
  t.assert_false(second_valid, "second tab buffer validity")
  t.assert_false(third_valid, "third tab buffer validity")
end)

t:run()
