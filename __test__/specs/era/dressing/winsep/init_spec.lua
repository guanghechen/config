--- Run with: nvim -l __test__/run.lua era/dressing/winsep/
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
local nvim_fn = require("stl.nvim.fn")
local t = harness.new("era.dressing.winsep")
local module_name = "era.dressing.winsep"

local function setup(initially_enabled)
  local runtime = {
    enabled = initially_enabled,
    fixed_winnr = vim.api.nvim_get_current_win(),
    debounce_calls = 0,
    observers = {},
    groups = {},
    shown = {},
    hidden = 0,
  }
  local observable = {
    snapshot = function()
      return runtime.enabled
    end,
  }
  t:patch_global("dot", {
    var = { zindex = { WINSEP = 50 } },
    context = { flight = { dressing_winsep = observable } },
    tab = {
      retrieve_winnr_fixed = function(tabnr)
        t.assert_eq(vim.api.nvim_get_current_tabpage(), tabnr, "observed tab")
        return runtime.fixed_winnr
      end,
    },
  })
  t:patch_global("stl", {
    timer = {
      debounce = function(callback, delay)
        runtime.debounce_calls = runtime.debounce_calls + 1
        t.assert_eq(32, delay, "debounce delay")
        return callback
      end,
    },
    fn = {
      observe = function(observables, callback, ignore_initial)
        t.assert_eq(observable, observables[1], "observed flight")
        t.assert_true(ignore_initial, "initial notification ignored")
        runtime.observers[#runtime.observers + 1] = callback
        return { unsubscribe = function() end }
      end,
    },
    nvim = {
      fn = {
        augroup = function(name)
          local group = nvim_fn.augroup(name)
          if runtime.groups[name] == nil then
            t:defer(function()
              vim.api.nvim_del_augroup_by_id(group)
            end)
          end
          runtime.groups[name] = group
          return group
        end,
      },
      win = {
        is_fixed = function(winnr)
          return winnr == runtime.fixed_winnr
        end,
      },
    },
  })
  t:patch_table(vim, "schedule", function(callback)
    callback()
  end)
  t:patch_table(package.loaded, module_name, nil)
  t:patch_table(package.loaded, module_name .. ".line", nil)
  t:patch_global("era", require("era"))
  t.assert_eq(module_name, era.dressing.__mods.winsep, "module registration")
  t.assert_nil(era.m.__mods.winsep, "old registration removed")
  runtime.module = era.dressing.winsep
  t.assert_eq(require(module_name .. ".line"), runtime.module.Line, "line module namespace")
  t:patch_table(runtime.module.Winsep, "show", function(_, winnr)
    runtime.shown[#runtime.shown + 1] = winnr
  end)
  t:patch_table(runtime.module.Winsep, "hide", function()
    runtime.hidden = runtime.hidden + 1
  end)
  runtime.notify = function()
    for _, observer in ipairs(runtime.observers) do
      observer()
    end
  end
  return runtime
end

t:test("dressing creates one debounce and observer and preserves window callbacks", function()
  local runtime = setup(true)
  runtime.module.dressing()
  local resize_group = runtime.groups[module_name .. "_on_resize"]
  local enter_group = runtime.groups[module_name .. "_on_WinEnter"]
  local resize_events = vim.api.nvim_get_autocmds({ group = resize_group })
  local enter_events = vim.api.nvim_get_autocmds({ group = enter_group })

  runtime.module.dressing()
  t.assert_eq(1, runtime.debounce_calls, "debounce allocations")
  t.assert_eq(1, #runtime.observers, "observer registrations")
  t.assert_eq(2, #resize_events, "resize events")
  t.assert_eq(1, #enter_events, "window entry event")
  t.assert_true(
    vim.deep_equal(resize_events, vim.api.nvim_get_autocmds({ group = resize_group })),
    "resize callbacks preserved"
  )
  t.assert_true(
    vim.deep_equal(enter_events, vim.api.nvim_get_autocmds({ group = enter_group })),
    "entry callback preserved"
  )

  runtime.notify()
  vim.api.nvim_exec_autocmds("WinResized", { group = resize_group, modeline = false })
  vim.api.nvim_exec_autocmds("WinEnter", { group = enter_group, modeline = false })
  t.assert_true(
    vim.deep_equal({ runtime.fixed_winnr, runtime.fixed_winnr, runtime.fixed_winnr }, runtime.shown),
    "flight and window events refresh the fixed window"
  )
end)

t:test("dressing initializes while disabled and reuses its observer across toggles", function()
  local runtime = setup(false)
  runtime.module.dressing()
  runtime.module.dressing()
  t.assert_eq(1, runtime.debounce_calls, "debounce allocations while disabled")
  t.assert_eq(1, #runtime.observers, "observer registrations while disabled")

  runtime.notify()
  t.assert_eq(1, runtime.hidden, "disabled separators hidden")
  runtime.enabled = true
  runtime.notify()
  t.assert_true(vim.deep_equal({ runtime.fixed_winnr }, runtime.shown), "enabled separators shown")
  runtime.module.dressing()
  runtime.enabled = false
  runtime.notify()
  t.assert_eq(2, runtime.hidden, "separators hidden again")
  t.assert_eq(1, #runtime.observers, "observer reused after toggles")
  t.assert_eq(1, runtime.debounce_calls, "debounce reused after toggles")

  runtime.fixed_winnr = nil
  vim.api.nvim_exec_autocmds("WinEnter", { group = runtime.groups[module_name .. "_on_WinEnter"], modeline = false })
  t.assert_eq(1, #runtime.shown, "non-fixed window ignored")
  t.assert_eq(2, runtime.hidden, "non-fixed window does not refresh")
end)

t:run()
