---@diagnostic disable: undefined-global
--- Test for tmux state refreshes in dot.autocmd
--- Run with: nvim -l lua/__test__/dot/autocmd.lua

local harness = require("__test__.harness")

local t = harness.new("dot.autocmd")

---@class dot.autocmd.test.IRuntime
---@field autocmds                    table<string, table>
---@field queries                     fun(is_zoomed: boolean|nil)[]
---@field scheduled                   fun()[]
---@field updates                     boolean[]
---@field disposed                    integer
---@field tab_close_argc               integer|nil
---@field tab_delete_bufnr             integer|nil
---@field buf_close_bufnr              integer|nil
---@field term_delete_bufnr            integer|nil
---@field current_tabnr                integer
---@field equalized_tabnrs             integer[]
---@field status_updates               integer
---@field saved_on_exit                integer
---@field save_on_exit_error           boolean
---@field save_errors                  integer
---@field shutdown_steps               string[]

---@param vim_did_enter                ?integer
---@return dot.autocmd.test.IRuntime
local function setup(vim_did_enter)
  local runtime = {
    autocmds = {},
    queries = {},
    scheduled = {},
    updates = {},
    disposed = 0,
    tab_close_argc = nil,
    tab_delete_bufnr = nil,
    buf_close_bufnr = nil,
    term_delete_bufnr = nil,
    current_tabnr = 1,
    equalized_tabnrs = {},
    status_updates = 0,
    saved_on_exit = 0,
    save_on_exit_error = false,
    save_errors = 0,
    shutdown_steps = {},
  } ---@type dot.autocmd.test.IRuntime

  t:patch_global("stl", {
    env = { IS_TMUX = true },
    nvim = {
      fn = {
        augroup = function(name)
          return name
        end,
      },
      win = {
        is_fixed = function()
          return true
        end,
      },
    },
    tmux = {
      query_tmux_pane_zoomed = function(callback)
        runtime.queries[#runtime.queries + 1] = function(is_zoomed)
          runtime.scheduled[#runtime.scheduled + 1] = function()
            callback(is_zoomed)
          end
        end
      end,
    },
    reporter = {
      error = function()
        runtime.save_errors = runtime.save_errors + 1
      end,
    },
  })
  t:patch_global("dot", {
    tab = {
      equalize = function(tabnr)
        runtime.equalized_tabnrs[#runtime.equalized_tabnrs + 1] = tabnr
      end,
      on_buf_delete = function(bufnr)
        runtime.tab_delete_bufnr = bufnr
      end,
      on_close = function(...)
        runtime.tab_close_argc = select("#", ...)
      end,
      resolve = function()
        return nil
      end,
    },
    buf = {
      on_close = function(bufnr)
        runtime.buf_close_bufnr = bufnr
      end,
    },
    context = {
      save_on_exit = function()
        runtime.saved_on_exit = runtime.saved_on_exit + 1
        runtime.shutdown_steps[#runtime.shutdown_steps + 1] = "context"
        if runtime.save_on_exit_error then
          error("injected context save failure")
        end
      end,
    },
    state = {
      status = {
        dirty_winline_nr = {
          next = function()
            runtime.status_updates = runtime.status_updates + 1
          end,
        },
        dirtier_statusline = {
          mark_dirty = function()
            runtime.status_updates = runtime.status_updates + 1
          end,
        },
        dirtier_tabline = {
          mark_dirty = function()
            runtime.status_updates = runtime.status_updates + 1
          end,
        },
        isdisposed = function()
          return runtime.disposed > 0
        end,
        tmux_zen_mode = {
          next = function(_, value)
            runtime.updates[#runtime.updates + 1] = value
          end,
        },
        dispose = function()
          runtime.disposed = runtime.disposed + 1
          runtime.shutdown_steps[#runtime.shutdown_steps + 1] = "status"
        end,
      },
      widget = { resize = function() end },
    },
    win = {
      is_sourcefile = function()
        return false
      end,
    },
  })
  t:patch_global("era", {
    m = {
      term = {
        event = {
          on_buf_deleted = function(bufnr)
            runtime.term_delete_bufnr = bufnr
          end,
        },
      },
    },
  })
  t:patch_global("yoz", {})
  t:patch_table(vim.v, "vim_did_enter", vim_did_enter or 0)
  t:patch_table(vim, "schedule", function(callback)
    runtime.scheduled[#runtime.scheduled + 1] = callback
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(_, opts)
    runtime.autocmds[opts.group] = opts
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_current_tabpage", function()
    return runtime.current_tabnr
  end)
  t:patch_table(vim.api, "nvim_tabpage_get_win", function()
    return 10
  end)
  t:patch_table(vim.api, "nvim_tabpage_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)

  assert(loadfile("lua/dot/autocmd.lua"))()
  return runtime
end

---@param runtime                      dot.autocmd.test.IRuntime
---@return nil
local function run_scheduled(runtime)
  while #runtime.scheduled > 0 do
    local callback = table.remove(runtime.scheduled, 1)
    callback()
  end
end

t:test("startup SessionLoadPost does not duplicate the VimEnter query", function()
  local runtime = setup(0)

  runtime.autocmds.state_tmux_zen_mode_on_SessionLoadPost.callback()

  t.assert_eq(0, #runtime.queries, "tmux queries")
end)

t:test("runtime SessionLoadPost corrects state reset during restore", function()
  local runtime = setup(1)

  runtime.autocmds.state_tmux_zen_mode_on_SessionLoadPost.callback()
  t.assert_eq(1, #runtime.queries, "tmux queries")

  runtime.queries[1](false)
  dot.state.status.tmux_zen_mode:next(true)
  run_scheduled(runtime)

  t.assert_eq(2, #runtime.updates, "state updates")
  t.assert_true(runtime.updates[1], "session reset")
  t.assert_false(runtime.updates[2], "restored tmux state")
end)

t:test("TabClosed delegates without passing the ordinal as a handle", function()
  local runtime = setup()

  runtime.autocmds.bootstrap_on_TabClosed.callback({ file = "2" })

  t.assert_eq(0, runtime.tab_close_argc, "tab close arguments")
end)

t:test("BufDelete forwards the deleted buffer to every owner", function()
  local runtime = setup()

  runtime.autocmds.bootstrap_on_BufDelete.callback({ buf = 42 })

  t.assert_eq(42, runtime.tab_delete_bufnr, "tab metadata")
  t.assert_eq(42, runtime.buf_close_bufnr, "buffer metadata")
  t.assert_eq(42, runtime.term_delete_bufnr, "terminal metadata")
end)

t:test("concurrent refreshes keep one query in flight and apply the final result", function()
  local runtime = setup()
  local vim_enter = runtime.autocmds.state_tmux_zen_mode_on_VimEnter.callback

  vim_enter()
  vim_enter()
  t.assert_eq(1, #runtime.queries, "in-flight queries")

  runtime.queries[1](false)
  run_scheduled(runtime)
  t.assert_eq(2, #runtime.queries, "trailing query")
  t.assert_eq(0, #runtime.updates, "stale result must not apply")

  runtime.queries[2](true)
  run_scheduled(runtime)
  t.assert_eq(1, #runtime.updates, "final updates")
  t.assert_true(runtime.updates[1], "final state")
end)

t:test("VimResized equalizes only the current tab and refreshes state", function()
  local runtime = setup()

  runtime.autocmds.bootstrap_on_VimResized.callback()
  t.assert_eq(1, #runtime.scheduled, "scheduled resize callbacks")
  t.assert_eq(1, #runtime.equalized_tabnrs, "equalized tabs")
  t.assert_eq(1, runtime.equalized_tabnrs[1], "current tab")
  t.assert_eq(0, #runtime.queries, "before scheduled resize work")

  table.remove(runtime.scheduled, 1)()
  t.assert_eq(1, #runtime.queries, "resize query")
  t.assert_eq(0, #runtime.scheduled, "nested scheduled callbacks")
end)

t:test("failed query preserves the current state and permits retry", function()
  local runtime = setup()

  runtime.autocmds.state_tmux_zen_mode_on_VimEnter.callback()
  runtime.queries[1](nil)
  run_scheduled(runtime)

  t.assert_eq(0, #runtime.updates, "state updates")

  runtime.autocmds.state_tmux_zen_mode_on_VimEnter.callback()
  t.assert_eq(2, #runtime.queries, "retry query")
end)

t:test("VimLeavePre prevents an in-flight query from updating disposed state", function()
  local runtime = setup()

  runtime.autocmds.state_tmux_zen_mode_on_VimEnter.callback()
  runtime.autocmds.state_on_VimLeavePre.callback()
  runtime.queries[1](false)
  run_scheduled(runtime)

  t.assert_eq(1, runtime.disposed, "dispose calls")
  t.assert_eq(0, #runtime.updates, "updates after dispose")
end)

t:test("VimLeavePre saves context before disposing status", function()
  local runtime = setup()

  runtime.autocmds.state_on_VimLeavePre.callback()

  t.assert_eq(1, runtime.saved_on_exit, "context save calls")
  t.assert_eq("context", runtime.shutdown_steps[1], "first shutdown step")
  t.assert_eq("status", runtime.shutdown_steps[2], "second shutdown step")
end)

t:test("VimLeavePre still disposes status when context save fails", function()
  local runtime = setup()
  runtime.save_on_exit_error = true

  runtime.autocmds.state_on_VimLeavePre.callback()

  t.assert_eq(1, runtime.saved_on_exit, "context save attempts")
  t.assert_eq(1, runtime.disposed, "status dispose calls")
  t.assert_eq(1, runtime.save_errors, "reported save failures")
end)

t:test("VimLeavePre drops deferred window updates after status disposal", function()
  local runtime = setup()

  runtime.autocmds.bootstrap_on_WinEnter.callback()
  t.assert_eq(1, #runtime.scheduled, "deferred window updates")

  runtime.autocmds.state_on_VimLeavePre.callback()
  run_scheduled(runtime)

  t.assert_eq(1, runtime.disposed, "dispose calls")
  t.assert_eq(0, runtime.status_updates, "status updates after dispose")
end)

t:run()
