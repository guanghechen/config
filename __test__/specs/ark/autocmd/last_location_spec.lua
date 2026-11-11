local ark_autocmd = require("__test__.support.ark_autocmd")
local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

---@class ark.autocmd.test.IRuntime
---@field autocmds                      table<string, table>
---@field autocmd_events                table<string, string|string[]>
---@field schedule                      __test__.support.bootstrap.ISchedule
---@field bufnr                         integer
---@field winnr                         integer
---@field valid                         boolean
---@field cursor_updates                integer
---@field accepted                      integer
---@field cursor_error                  boolean

---@return ark.autocmd.test.IRuntime
local function setup()
  local runtime = {
    autocmds = {},
    autocmd_events = {},
    schedule = bootstrap.with_schedule(t),
    bufnr = 1,
    winnr = 11,
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
    dressing = {
      scroll = {
        accept_current_view = function()
          runtime.accepted = runtime.accepted + 1
        end,
      },
    },
    m = {
      python_venv = { dressing = function() end },
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
  t:patch_table(vim.filetype, "add", function() end)
  ark_autocmd.record(t, runtime.autocmds, runtime.autocmd_events)
  t:patch_table(vim.api, "nvim_get_current_win", function()
    return runtime.winnr
  end)
  t:patch_table(vim.api, "nvim_win_get_buf", function()
    return runtime.bufnr
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function(winnr)
    return runtime.valid and winnr == runtime.winnr
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
  runtime.autocmds.ark_goto_last_location_read.callback({ buf = 1 })
  runtime.autocmds.ark_goto_last_location.callback({ buf = 1 })
  t.assert_eq(1, #runtime.schedule.callbacks, "scheduled callbacks")
end

t:test("accepts the restored cursor position as the scroll baseline", function()
  local runtime = setup()
  schedule_last_location(runtime)

  runtime.schedule.drain()

  t.assert_eq(1, runtime.cursor_updates, "cursor updates")
  t.assert_eq(1, runtime.accepted, "accepted views")
end)

t:test("a window that disappears before restoration does not consume the saved cursor", function()
  local runtime = setup()
  schedule_last_location(runtime)
  runtime.valid = false
  runtime.schedule.drain()
  t.assert_eq(0, runtime.accepted, "expired window has no scroll baseline")
  t.assert_false(vim.b[1].eve_last_loc, "saved cursor remains pending")

  runtime.valid = true
  runtime.winnr = 12
  t.assert_eq("BufWinEnter", runtime.autocmd_events.ark_goto_last_location, "restore on display")
  schedule_last_location(runtime)
  runtime.schedule.drain()
  t.assert_eq(2, runtime.cursor_updates, "first real display restores the cursor again")
end)

t:test("repeated entry events restore the saved cursor only once", function()
  local runtime = setup()
  schedule_last_location(runtime)
  runtime.autocmds.ark_goto_last_location.callback({ buf = 1 })
  t.assert_eq(1, #runtime.schedule.callbacks, "one pending restoration")
  runtime.schedule.drain()
  t.assert_eq(1, runtime.cursor_updates, "one cursor restoration")
end)

t:test("does not commit restoration when the window changes buffers before the scheduled callback", function()
  local runtime = setup()
  schedule_last_location(runtime)

  runtime.bufnr = 2
  runtime.schedule.drain()

  t.assert_false(vim.b[1].eve_last_loc, "restoration remains pending after the buffer changed")
  t.assert_nil(vim.b[1].eve_last_loc_winnr, "stale window claim released")
  t.assert_eq(0, runtime.accepted, "accepted views")
end)

t:test("does not accept a baseline when restoring the cursor fails", function()
  local runtime = setup()
  runtime.cursor_error = true
  schedule_last_location(runtime)
  runtime.schedule.drain()

  t.assert_eq(0, runtime.cursor_updates, "cursor updates")
  t.assert_eq(0, runtime.accepted, "accepted views")
end)

for _, filetype in ipairs({ "gitcommit", "gitrebase" }) do
  t:test(filetype .. " starts at the top instead of the position saved for its previous content", function()
    local runtime = setup()
    local get_option_value = vim.api.nvim_get_option_value
    t:patch_table(vim.api, "nvim_get_option_value", function(name, opts)
      return name == "filetype" and filetype or get_option_value(name, opts)
    end)

    runtime.autocmds.ark_goto_last_location_read.callback({ buf = 1 })
    runtime.autocmds.ark_goto_last_location.callback({ buf = 1 })
    t.assert_eq(0, #runtime.schedule.callbacks, "scheduled restorations")
    t.assert_eq(0, runtime.cursor_updates, "cursor updates")
  end)
end

t:run()
