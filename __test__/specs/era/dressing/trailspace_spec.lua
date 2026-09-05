--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/trailspace_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
local nvim_fn = require("stl.nvim.fn")
local t = harness.new("era.dressing.trailspace")
local module_name = "era.dressing.trailspace"
local hlgroup = "f_ux_trailspace"

local function setup(initially_enabled)
  local runtime = { enabled = initially_enabled, observers = {}, augroup_calls = 0 }
  local bufnr = vim.api.nvim_create_buf(false, false)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local winnr = vim.api.nvim_open_win(bufnr, true, { split = "right" })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "local value = 1  " })
  local previous_hl = vim.api.nvim_get_hl(0, { name = hlgroup, create = false })
  t:defer(function()
    vim.api.nvim_set_hl(0, hlgroup, previous_hl)
  end)
  vim.api.nvim_set_hl(0, hlgroup, { bg = 0xff0000 })

  local observable = {
    snapshot = function()
      return runtime.enabled
    end,
  }
  t:patch_global("dot", { context = { flight = { dressing_trailspace = observable } } })
  t:patch_global("stl", {
    filetype = require("stl.filetype"),
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
          t.assert_eq(module_name, name, "augroup name")
          runtime.augroup_calls = runtime.augroup_calls + 1
          local group = nvim_fn.augroup(name)
          if runtime.augroup_calls == 1 then
            t:defer(function()
              vim.api.nvim_del_augroup_by_id(group)
            end)
          end
          runtime.group = group
          return group
        end,
      },
    },
  })

  runtime.trailspace = assert(loadfile("lua/era/dressing/trailspace.lua"))()
  runtime.set_enabled = function(enabled)
    runtime.enabled = enabled
    for _, observer in ipairs(runtime.observers) do
      observer()
    end
  end
  return runtime
end

t:test("dressing preserves one observer and its autocmds across repeated calls", function()
  local runtime = setup(true)
  runtime.trailspace.dressing()
  local autocmds = vim.api.nvim_get_autocmds({ group = runtime.group })
  t.assert_eq(6, #autocmds, "registered lifecycle events")
  vim.api.nvim_exec_autocmds("BufEnter", { group = runtime.group, modeline = false })
  t.assert_eq(1, #vim.fn.getmatches(), "active highlight")

  runtime.trailspace.dressing()
  t.assert_eq(1, #runtime.observers, "observer registrations")
  t.assert_eq(1, runtime.augroup_calls, "augroup registrations")
  t.assert_true(
    vim.deep_equal(autocmds, vim.api.nvim_get_autocmds({ group = runtime.group })),
    "autocmds are preserved"
  )

  runtime.set_enabled(false)
  runtime.trailspace.dressing()
  t.assert_eq(1, #runtime.observers, "observer registrations while disabled")
  t.assert_eq(0, #vim.fn.getmatches(), "disabled highlight")
  runtime.set_enabled(true)
  t.assert_eq(1, #vim.fn.getmatches(), "re-enabled highlight")
end)

t:test("dressing subscribes once when initially disabled and responds to later toggles", function()
  local runtime = setup(false)
  runtime.trailspace.dressing()
  runtime.trailspace.dressing()
  t.assert_eq(1, #runtime.observers, "observer registrations while initially disabled")
  t.assert_eq(0, #vim.fn.getmatches(), "initially disabled highlight")

  runtime.set_enabled(true)
  runtime.trailspace.dressing()
  t.assert_eq(1, #runtime.observers, "observer registrations after enabling")
  t.assert_eq(1, #vim.fn.getmatches(), "enabled highlight")
  runtime.set_enabled(false)
  t.assert_eq(0, #vim.fn.getmatches(), "disabled highlight")
  t.assert_eq(1, runtime.augroup_calls, "augroup registrations")
end)

t:run()
