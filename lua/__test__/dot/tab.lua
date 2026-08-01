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

t:run()
