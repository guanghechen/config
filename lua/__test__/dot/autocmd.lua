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

---@param vim_did_enter                ?integer
---@return dot.autocmd.test.IRuntime
local function setup(vim_did_enter)
  local runtime = {
    autocmds = {},
    queries = {},
    scheduled = {},
    updates = {},
    disposed = 0,
  } ---@type dot.autocmd.test.IRuntime

  t:patch_global("stl", {
    env = { IS_TMUX = true },
    nvim = {
      fn = {
        augroup = function(name)
          return name
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
  })
  t:patch_global("dot", {
    state = {
      status = {
        dirtier_statusline = { mark_dirty = function() end },
        dirtier_tabline = { mark_dirty = function() end },
        tmux_zen_mode = {
          next = function(_, value)
            runtime.updates[#runtime.updates + 1] = value
          end,
        },
        dispose = function()
          runtime.disposed = runtime.disposed + 1
        end,
      },
      widget = { resize = function() end },
    },
  })
  t:patch_global("era", {})
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
    return 1
  end)
  t:patch_table(vim.api, "nvim_tabpage_get_win", function()
    return 11
  end)
  t:patch_table(vim.api, "nvim_list_tabpages", function()
    return { 1 }
  end)
  t:patch_table(vim.api, "nvim_tabpage_list_wins", function()
    return { 11 }
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_win_call", function(_, callback)
    callback()
  end)
  t:patch_table(vim.api, "nvim_tabpage_set_win", function() end)
  t:patch_table(vim, "cmd", function() end)

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

t:test("VimResized refreshes tmux state without a nested scheduled query", function()
  local runtime = setup()

  runtime.autocmds.bootstrap_on_VimResized.callback()
  t.assert_eq(1, #runtime.scheduled, "scheduled resize callbacks")
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

t:run()
