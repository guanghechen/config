---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/plugin/loader.lua

local harness = require("__test__.harness")
local loader = require("era.m.plugin.loader")

local t = harness.new("era.m.plugin.loader")

---@param specs                         table<string, era.m.plugin.IPluginSpec>
---@return table<string, era.m.plugin.IPluginState>
local function states_of(specs)
  local states = {} ---@type table<string, era.m.plugin.IPluginState>
  for name, spec in pairs(specs) do
    states[name] = { spec = spec, loaded = false } ---@type era.m.plugin.IPluginState
  end
  return states
end

t:test("a dependency re-entering the parent runs each body once", function()
  local runs = {} ---@type string[]
  local states = states_of({
    parent = {
      name = "parent",
      dependencies = { "child" },
      config = function()
        runs[#runs + 1] = "parent"
      end,
    },
    child = {
      name = "child",
      config = function()
        runs[#runs + 1] = "child"
        loader.__load_plugin__(loader.plugins.parent)
      end,
    },
  })
  t:patch_table(loader, "plugins", states)

  loader.__load_plugin__(states.parent)

  t.assert_eq("child,parent", table.concat(runs, ","), "plugin body order")
end)

t:test("mutual dependencies each run once", function()
  local runs = {} ---@type string[]
  local states = states_of({
    a = {
      name = "a",
      dependencies = { "b" },
      config = function()
        runs[#runs + 1] = "a"
      end,
    },
    b = {
      name = "b",
      dependencies = { "a" },
      config = function()
        runs[#runs + 1] = "b"
      end,
    },
  })
  t:patch_table(loader, "plugins", states)

  loader.__load_plugin__(states.a)

  t.assert_eq("b,a", table.concat(runs, ","), "plugin body order")
  t.assert_true(states.a.loaded, "plugin a loaded")
  t.assert_true(states.b.loaded, "plugin b loaded")
end)

t:test("the parent is marked loaded before dependencies run", function()
  local seen_loaded = false
  local states = states_of({
    parent = { name = "parent", dependencies = { "child" }, config = function() end },
    child = {
      name = "child",
      config = function()
        seen_loaded = loader.plugins.parent.loaded
      end,
    },
  })
  t:patch_table(loader, "plugins", states)

  loader.__load_plugin__(states.parent)

  t.assert_true(seen_loaded, "parent load guard")
end)

t:test("a dependency failure leaves the parent retryable", function()
  local runs = {} ---@type string[]
  local states = states_of({
    parent = {
      name = "parent",
      dependencies = { "child" },
      config = function()
        runs[#runs + 1] = "parent"
      end,
    },
    child = {
      name = "child",
      config = function()
        error("dependency failed")
      end,
    },
  })
  t:patch_table(loader, "plugins", states)

  local ok = pcall(loader.__load_plugin__, states.parent) ---@type boolean
  t.assert_false(ok, "dependency failure")
  t.assert_false(states.parent.loaded, "parent retry guard")

  loader.__load_plugin__(states.parent)

  t.assert_true(states.parent.loaded, "parent retried")
  t.assert_eq("parent", table.concat(runs, ","), "parent config")
end)

t:run()
