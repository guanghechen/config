---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/plugin/loader.lua

local harness = require("__test__.harness")
local loader = require("era.m.plugin.loader")

local t = harness.new("era.m.plugin.loader")

-- PluginLoad delivery is tested explicitly below; other tests do not need to drain scheduled callbacks.
t:patch_table(vim, "schedule", function() end)

---@param specs                         table<string, era.m.plugin.IPluginSpec>
---@return table<string, era.m.plugin.IPluginState>
local function states_of(specs)
  local states = {} ---@type table<string, era.m.plugin.IPluginState>
  for name, spec in pairs(specs) do
    states[name] = { spec = spec, loaded = false, loading = false } ---@type era.m.plugin.IPluginState
  end
  return states
end

---@param specs                         table<string, era.m.plugin.IPluginSpec>
---@return table<string, era.m.plugin.IPluginState>
local function use_states(specs)
  local states = states_of(specs)
  t:patch_table(loader, "plugins", states)
  return states
end

t:test("plugin registration maps only explicit main modules", function()
  t:patch_table(loader, "plugins", {})
  t:patch_table(loader, "_module_to_plugin", {})
  t:patch_table(loader, "__resolve_plugin_path__", function()
    return nil
  end)

  loader.__register_plugins__({
    { name = "explicit", main = "explicit.main" },
    { name = "data-only" },
  })

  t.assert_eq("explicit", loader._module_to_plugin["explicit.main"], "explicit main mapping")
  t.assert_nil(loader._module_to_plugin["data-only"], "inferred main mapping")
  t.assert_false(loader.plugins.explicit.loaded, "initial loaded state")
  t.assert_false(loader.plugins.explicit.loading, "initial loading state")
end)

t:test("a dependency re-entering the parent runs each body once", function()
  local runs = {} ---@type string[]
  local parent_loading = false
  local parent_loaded = true
  local states = use_states({
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
        parent_loading = loader.plugins.parent.loading
        parent_loaded = loader.plugins.parent.loaded
        loader.__load_plugin__(loader.plugins.parent)
      end,
    },
  })

  loader.__load_plugin__(states.parent)

  t.assert_eq("child,parent", table.concat(runs, ","), "plugin body order")
  t.assert_true(parent_loading, "parent re-entry guard")
  t.assert_false(parent_loaded, "parent success state during dependency load")
  t.assert_true(states.parent.loaded, "parent loaded")
  t.assert_false(states.parent.loading, "parent loading")
end)

t:test("mutual dependencies each run once", function()
  local runs = {} ---@type string[]
  local states = use_states({
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

  loader.__load_plugin__(states.a)

  t.assert_eq("b,a", table.concat(runs, ","), "plugin body order")
  t.assert_true(states.a.loaded, "plugin a loaded")
  t.assert_true(states.b.loaded, "plugin b loaded")
  t.assert_false(states.a.loading, "plugin a loading")
  t.assert_false(states.b.loading, "plugin b loading")
end)

t:test("a config failure releases the plugin state", function()
  local states = use_states({
    plugin = {
      name = "plugin",
      config = function()
        error("config failed")
      end,
    },
  })

  local ok = pcall(loader.__load_plugin__, states.plugin)

  t.assert_false(ok, "config failure")
  t.assert_false(states.plugin.loaded, "loaded after failure")
  t.assert_false(states.plugin.loading, "loading after failure")
end)

t:test("a dependency failure releases both plugin states", function()
  local states = use_states({
    parent = {
      name = "parent",
      dependencies = { "child" },
      config = function() end,
    },
    child = {
      name = "child",
      config = function()
        error("dependency failed")
      end,
    },
  })

  local ok = pcall(loader.__load_plugin__, states.parent) ---@type boolean
  t.assert_false(ok, "dependency failure")
  t.assert_false(states.parent.loaded, "parent loaded after failure")
  t.assert_false(states.parent.loading, "parent loading after failure")
  t.assert_false(states.child.loaded, "child loaded after failure")
  t.assert_false(states.child.loading, "child loading after failure")
end)

t:test("a main require failure restores its cache before a later explicit load", function()
  local module_name = "__test__.era.m.plugin.loader.retry_main"
  local attempts = 0
  local setup_runs = 0
  local scheduled = {} ---@type fun()[]
  local events = {} ---@type table[]

  t:patch_table(package.loaded, module_name, nil)
  t:patch_table(package.preload, module_name, function()
    attempts = attempts + 1
    if attempts == 1 then
      error("main failed")
    end
    return {
      setup = function()
        setup_runs = setup_runs + 1
      end,
    }
  end)
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)
  t:patch_table(vim.api, "nvim_exec_autocmds", function(event, opts)
    events[#events + 1] = { event = event, opts = opts }
  end)

  local states = use_states({
    plugin = { name = "plugin", main = module_name },
  })

  local ok = pcall(loader.__load_plugin__, states.plugin)

  t.assert_false(ok, "main failure")
  t.assert_false(states.plugin.loaded, "loaded after main failure")
  t.assert_false(states.plugin.loading, "loading after main failure")
  t.assert_eq(0, #scheduled, "events after main failure")

  loader.__load_plugin__(states.plugin)

  t.assert_true(states.plugin.loaded, "loaded after main retry")
  t.assert_eq(2, attempts, "main attempts")
  t.assert_eq(1, setup_runs, "setup runs")
  t.assert_eq(1, #scheduled, "scheduled PluginLoad events")

  scheduled[1]()
  t.assert_eq(1, #events, "PluginLoad events")
  t.assert_eq("User", events[1].event, "PluginLoad event")
  t.assert_eq("PluginLoad", events[1].opts.pattern, "PluginLoad pattern")
  t.assert_eq("plugin", events[1].opts.data, "PluginLoad data")
end)

t:test("a config require failure restores the primary module cache", function()
  local module_name = "__test__.era.m.plugin.loader.retry_config_main"

  t:patch_table(package.loaded, module_name, nil)
  t:patch_table(package.preload, module_name, function()
    error("config main failed")
  end)

  local states = use_states({
    plugin = {
      name = "plugin",
      main = module_name,
      config = function()
        require(module_name)
      end,
    },
  })

  local ok = pcall(loader.__load_plugin__, states.plugin)

  t.assert_false(ok, "config require failure")
  t.assert_false(states.plugin.loaded, "loaded after config require failure")
  t.assert_false(states.plugin.loading, "loading after config require failure")
  t.assert_nil(package.loaded[module_name], "main cache after config require failure")
end)

t:run()
