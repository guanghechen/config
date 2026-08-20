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
    states[name] = { spec = spec, loaded = false, loading = false, startup = false } ---@type era.m.plugin.IPluginState
  end
  return states
end

---@param specs                         table<string, era.m.plugin.IPluginSpec>
---@return table<string, era.m.plugin.IPluginState>
local function use_states(specs)
  local states = states_of(specs)
  t:patch_table(loader, "plugins", states)
  t:patch_table(loader, "_load_depth", 0)
  t:patch_table(loader, "_nvim_startup_time", nil)
  t:patch_table(loader, "_startup_complete", false)
  t:patch_table(loader, "_startup_load_time", 0)
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

t:test("nvim startup time uses the process start timestamp once", function()
  use_states({})

  local current_time = vim.v.starttime + 25e6 ---@type number
  local seconds = math.floor(current_time / 1e9) ---@type integer
  local microseconds = math.floor((current_time - seconds * 1e9) / 1e3 + 0.5) ---@type integer
  t:patch_table(vim.uv, "gettimeofday", function()
    return seconds, microseconds
  end)

  loader.__record_nvim_startup__()
  local recorded = loader.get_startup_profile().nvim_startup_time ---@type number|nil
  t.assert_true(recorded ~= nil and math.abs(recorded - 25) < 0.001, "nvim startup time")

  t:patch_table(vim.uv, "gettimeofday", function()
    return seconds + 1, microseconds
  end)
  loader.__record_nvim_startup__()
  t.assert_eq(recorded, loader.get_startup_profile().nvim_startup_time, "nvim startup time recorded once")
end)

t:test("startup total counts a nested dependency once", function()
  local times = { 0, 10e6, 30e6, 50e6 }
  local time_index = 0
  t:patch_table(vim.uv, "hrtime", function()
    time_index = time_index + 1
    return times[time_index]
  end)

  local states = use_states({
    parent = {
      name = "parent",
      dependencies = { "child" },
      config = function() end,
    },
    child = {
      name = "child",
      config = function() end,
    },
  })

  loader.__load_plugin__(states.parent)

  local profile = loader.get_startup_profile()
  local names = vim.tbl_map(function(state)
    return state.spec.name
  end, profile.plugins)
  table.sort(names)

  t.assert_eq("child,parent", table.concat(names, ","), "startup plugins")
  t.assert_eq(20, states.child.load_time, "dependency inclusive load time")
  t.assert_eq(50, states.parent.load_time, "parent inclusive load time")
  t.assert_eq(50, profile.total_time, "startup total")
end)

t:test("startup profile ignores plugins loaded after finalization", function()
  local times = { 0, 10e6, 20e6, 50e6 }
  local time_index = 0
  t:patch_table(vim.uv, "hrtime", function()
    time_index = time_index + 1
    return times[time_index]
  end)

  local states = use_states({
    startup = { name = "startup", config = function() end },
    runtime = { name = "runtime", config = function() end },
  })

  loader.__load_plugin__(states.startup)
  loader.__complete_startup__()
  loader.__load_plugin__(states.runtime)

  local profile = loader.get_startup_profile()
  t.assert_eq(1, #profile.plugins, "startup plugin count")
  t.assert_eq("startup", profile.plugins[1].spec.name, "startup plugin")
  t.assert_eq(10, profile.total_time, "frozen startup total")
  t.assert_true(profile.finalized, "profile finalized")
  t.assert_false(states.runtime.startup, "runtime plugin startup membership")
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
