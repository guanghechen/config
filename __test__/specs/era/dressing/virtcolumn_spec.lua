--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/virtcolumn_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.virtcolumn")
local module_name = "era.dressing.virtcolumn" ---@type string
local observable = {
  snapshot = function()
    return true
  end,
}
local observe_calls = 0 ---@type integer
local augroup_calls = 0 ---@type integer
local autocmd_calls = 0 ---@type integer

bootstrap.with_runtime(t, {
  stl = {
    filetype = require("stl.filetype"),
    fn = {
      observe = function(observables, _, ignore_initial)
        observe_calls = observe_calls + 1
        t.assert_eq(observable, observables[1], "observed flight")
        t.assert_true(ignore_initial, "initial notification ignored")
        return { unsubscribe = function() end }
      end,
    },
    nvim = {
      fn = {
        augroup = function(name)
          augroup_calls = augroup_calls + 1
          t.assert_eq(module_name, name, "augroup name")
          return 1
        end,
      },
    },
    timer = {
      debounce = function(callback, delay)
        t.assert_eq(50, delay, "debounce delay")
        return callback
      end,
    },
  },
  dot = {
    context = {
      flight = {
        dressing_virtcolumn = observable,
      },
    },
    var = {
      nsnr = {
        virtcolumn = 1,
      },
    },
  },
})

t:patch_table(vim.api, "nvim_create_autocmd", function()
  autocmd_calls = autocmd_calls + 1
  return autocmd_calls
end)
t:patch_table(package.loaded, module_name, nil)

local Virtcolumn = require(module_name)

t:test("dressing initializes only once", function()
  Virtcolumn.dressing()
  Virtcolumn.dressing()

  t.assert_eq(1, observe_calls, "observer registrations")
  t.assert_eq(1, augroup_calls, "augroup registrations")
  t.assert_eq(1, autocmd_calls, "autocmd registrations")
end)

t:run()
