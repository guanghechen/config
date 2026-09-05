--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/init_spec.lua

local harness = require("__test__.support.harness")
local t = harness.new("era.dressing")

---@return era.dressing
local function fresh_dressing()
  t:patch_table(package.loaded, "era.dressing", nil)
  return require("era.dressing")
end

t:test("the namespace stays lazy and independent of the plugin manager", function()
  local dressing = fresh_dressing()
  local requires = 0
  local module = { dressing = function() end }
  t:patch_table(vim, "schedule", function() end)
  t:patch_table(package.loaded, "era", nil)
  t:patch_table(package.loaded, "era.dressing.virtcolumn", nil)
  t:patch_table(package.preload, "era.dressing.virtcolumn", function()
    requires = requires + 1
    return module
  end)

  t.assert_eq(dressing, require("era").dressing, "one namespace instance")
  t.assert_eq(0, requires, "namespace does not load its children")
  t.assert_eq("era.dressing.virtcolumn", dressing.__mods.virtcolumn, "module registration")
  t.assert_eq(module, dressing.virtcolumn, "lazy module access")
  t.assert_eq(module, dressing.virtcolumn, "cached require")
  t.assert_eq(1, requires, "child required once")
  t.assert_nil(next(dressing.get_load_times()), "module access does not run setup")

  dressing.setup({ "virtcolumn" })
  t.assert_nil(package.loaded["era.m.plugin"], "plugin entry remains unloaded")
  t.assert_nil(package.loaded["era.m.plugin.loader"], "plugin loader remains unloaded")
  t.assert_nil(package.loaded["era.m.plugin.state"], "plugin state remains unloaded")
end)

t:test("ordered setup records cold require and synchronous work once", function()
  local dressing = fresh_dressing()
  local clock, requires = 0, 0
  local calls, scheduled, events = {}, {}, {}
  t:patch_table(vim.uv, "hrtime", function()
    return clock
  end)
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)
  t:patch_table(vim.api, "nvim_exec_autocmds", function(event, options)
    t.assert_eq("User", event, "load event type")
    t.assert_eq("DressingLoad", options.pattern, "load event pattern")
    events[#events + 1] = options.data
  end)
  for _, name in ipairs({ "notifier", "ui_attach" }) do
    local module_name = dressing.__mods[name]
    t:patch_table(package.loaded, module_name, nil)
    t:patch_table(package.preload, module_name, function()
      requires = requires + 1
      clock = clock + 3e6
      return {
        dressing = function()
          calls[#calls + 1] = name
          clock = clock + 4e6
          vim.schedule(function()
            clock = clock + 100e6
          end)
        end,
      }
    end)
  end

  dressing.setup({ "notifier", "ui_attach" })
  t.assert_eq("notifier,ui_attach", table.concat(calls, ","), "requested setup order")
  t.assert_eq(7, dressing.get_load_times().notifier, "require plus setup in milliseconds")
  t.assert_eq(7, dressing.get_load_times().ui_attach, "independent module duration")
  t.assert_eq(0, #events, "events are deferred")
  for _, callback in ipairs(scheduled) do
    callback()
  end
  t.assert_eq("notifier,ui_attach", table.concat(events, ","), "one event per recorded module")
  t.assert_eq(7, dressing.get_load_times().notifier, "deferred work excluded")

  local snapshot = dressing.get_load_times()
  snapshot.notifier = 999
  scheduled = {}
  dressing.setup({ "notifier", "ui_attach" })
  t.assert_eq(2, requires, "module cache reused")
  t.assert_eq(4, #calls, "modules still own repeated setup")
  t.assert_eq(7, dressing.get_load_times().notifier, "first timing retained and snapshot isolated")
  t.assert_eq(2, #scheduled, "repeated setup only schedules the modules' own work")
end)

t:test("setup stops on failure and preserves completed timings for an explicit retry", function()
  local dressing = fresh_dressing()
  local failure = {}
  local clock, attempts, notifications = 0, 0, 0
  local calls = {}
  for _, name in ipairs({ "notifier", "ui_attach", "statusline" }) do
    t:patch_table(dressing, name, {
      dressing = function()
        calls[#calls + 1] = name
        clock = clock + 5e6
        if name == "ui_attach" then
          attempts = attempts + 1
          if attempts == 1 then
            error(failure)
          end
        end
      end,
    })
  end
  t:patch_table(vim.uv, "hrtime", function()
    return clock
  end)
  t:patch_table(vim, "schedule", function()
    notifications = notifications + 1
  end)

  local ok, err = pcall(dressing.setup, { "notifier", "ui_attach", "statusline" })
  t.assert_false(ok, "setup failure propagated")
  t.assert_eq(failure, err, "original error preserved")
  t.assert_eq("notifier,ui_attach", table.concat(calls, ","), "later modules are not run")
  t.assert_eq(5, dressing.get_load_times().notifier, "completed timing retained")
  t.assert_nil(dressing.get_load_times().ui_attach, "failed call has no timing")
  t.assert_nil(dressing.get_load_times().statusline, "unattempted module has no timing")
  t.assert_eq(1, notifications, "completed module still publishes its event")

  dressing.setup({ "ui_attach", "statusline" })
  t.assert_eq(2, attempts, "explicit retry reaches setup")
  t.assert_eq(5, dressing.get_load_times().ui_attach, "successful retry duration")
  t.assert_eq(5, dressing.get_load_times().statusline, "remaining module duration")
  t.assert_eq(3, notifications, "each successful module publishes one event")
end)

t:run()
