--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/whichkey/setup_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.dressing.whichkey.setup")

t:test("repeated dressing setup keeps one observer and still responds to toggles", function()
  local Whichkey = era.dressing.whichkey
  local setups, observations = 0, 0
  local enabled, active = false, false
  local observer = nil ---@type (fun())|nil
  t:patch_table(Whichkey, "state", {
    setup = function()
      setups = setups + 1
    end,
    enable = function()
      active = true
    end,
    disable = function()
      active = false
    end,
  })
  t:patch_table(dot, "context", {
    plugin = { which_key = {
      snapshot = function()
        return enabled
      end,
    } },
  })
  t:patch_table(stl.fn, "observe", function(_, callback)
    observations = observations + 1
    observer = callback
    callback()
  end)

  era.dressing.setup({ "whichkey" })
  era.dressing.setup({ "whichkey" })
  t.assert_eq(1, setups, "state initialized once")
  t.assert_eq(1, observations, "observer registered once")
  t.assert_true(era.dressing.get_load_times().whichkey ~= nil, "dressing timing recorded")
  t.assert_false(active, "initially disabled")

  enabled = true
  assert(observer)()
  t.assert_true(active, "enabled through observer")
  enabled = false
  assert(observer)()
  t.assert_false(active, "disabled through observer")
end)

t:run()
