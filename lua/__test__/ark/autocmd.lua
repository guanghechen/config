---@diagnostic disable: undefined-global
--- Test for ark.autocmd module
--- Run with: nvim -l lua/__test__/ark/autocmd.lua

local harness = require("__test__.harness")

local t = harness.new("ark.autocmd")

---@class ark.autocmd.test.IRuntime
---@field autocmds                      table<string, table>
---@field autocmd_events                table<string, string|string[]>
---@field scheduled                     fun()[]
---@field bufnr                         integer
---@field valid                         boolean
---@field cursor_updates                integer
---@field accepted                      integer
---@field cursor_error                  boolean

---@return ark.autocmd.test.IRuntime
local function setup()
  local runtime = {
    autocmds = {},
    autocmd_events = {},
    scheduled = {},
    bufnr = 1,
    valid = true,
    cursor_updates = 0,
    accepted = 0,
    cursor_error = false,
  } ---@type ark.autocmd.test.IRuntime

  t:patch_global("stl", {
    nvim = {
      buf = {
        on_buf_open = function() end,
        on_buf_close = function() end,
      },
    },
  })
  t:patch_global("dot", {})
  t:patch_global("era", {
    m = {
      python_venv = { dressing = function() end },
      scroll = {
        accept_current_view = function()
          runtime.accepted = runtime.accepted + 1
        end,
      },
    },
  })
  t:patch_global("yoz", {
    path = {
      dirname = function()
        return ""
      end,
      mkdirs = function() end,
    },
  })
  t:patch_table(vim, "b", { [1] = {} })
  t:patch_table(vim, "schedule", function(callback)
    runtime.scheduled[#runtime.scheduled + 1] = callback
  end)
  t:patch_table(vim.filetype, "add", function() end)
  t:patch_table(vim.api, "nvim_create_augroup", function(name)
    return name
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
    runtime.autocmds[opts.group] = opts
    runtime.autocmd_events[opts.group] = events
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_current_win", function()
    return 11
  end)
  t:patch_table(vim.api, "nvim_win_get_buf", function()
    return runtime.bufnr
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return runtime.valid
  end)
  t:patch_table(vim.api, "nvim_buf_get_mark", function()
    return { 20, 3 }
  end)
  t:patch_table(vim.api, "nvim_buf_line_count", function()
    return 100
  end)
  t:patch_table(vim.api, "nvim_win_set_cursor", function()
    if runtime.cursor_error then
      error("cursor update failed")
    end
    runtime.cursor_updates = runtime.cursor_updates + 1
  end)

  assert(loadfile("lua/ark/autocmd.lua"))()
  return runtime
end

---@param runtime                      ark.autocmd.test.IRuntime
---@return nil
local function schedule_last_location(runtime)
  runtime.autocmds.ark_goto_last_location.callback({ buf = 1 })
  t.assert_eq(1, #runtime.scheduled, "scheduled callbacks")
end

t:test("accepts the restored cursor position as the scroll baseline", function()
  local runtime = setup()
  schedule_last_location(runtime)

  table.remove(runtime.scheduled, 1)()

  t.assert_eq(1, runtime.cursor_updates, "cursor updates")
  t.assert_eq(1, runtime.accepted, "accepted views")
end)

t:test("does not restore a window that changed buffers before the scheduled callback", function()
  local runtime = setup()
  schedule_last_location(runtime)

  runtime.bufnr = 2
  table.remove(runtime.scheduled, 1)()

  t.assert_eq(0, runtime.cursor_updates, "cursor updates")
  t.assert_eq(0, runtime.accepted, "accepted views")
end)

t:test("does not accept a baseline when restoring the cursor fails", function()
  local runtime = setup()
  schedule_last_location(runtime)

  runtime.cursor_error = true
  table.remove(runtime.scheduled, 1)()

  t.assert_eq(0, runtime.cursor_updates, "cursor updates")
  t.assert_eq(0, runtime.accepted, "accepted views")
end)

t:test("refreshes the filepath cache after a buffer rename", function()
  local runtime = setup()
  local events = runtime.autocmd_events.ark_cache_buf_filepath

  t.assert_true(vim.deep_equal({ "BufWinEnter", "BufFilePost" }, events), "cache refresh events")
end)

t:run()
