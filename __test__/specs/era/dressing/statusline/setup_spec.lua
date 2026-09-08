--- Run with: nvim -l __test__/run.lua era/dressing/statusline/setup_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.dressing.statusline module

local harness = require("__test__.support.harness")
local nvim_fn = require("stl.nvim.fn")

local t = harness.new("era.dressing.statusline.setup")
local module_name = "era.dressing.statusline"

---@class era.dressing.statusline.test.IRuntime
---@field clean_count                  integer
---@field dirty                        boolean
---@field refresh_count                integer
---@field dispose_count                integer
---@field subscribers                  { on_next: fun() }[]
---@field group                        ?integer
---@field fulfill                      fun(result: string)
---@field mark_dirty                   fun()

---@return era.dressing.statusline.test.IRuntime, era.dressing.statusline
local function setup()
  local runtime = {
    clean_count = 0,
    dirty = true,
    refresh_count = 0,
    dispose_count = 0,
    subscribers = {},
  } ---@type era.dressing.statusline.test.IRuntime

  local winnr = vim.api.nvim_get_current_win()
  local previous_global = vim.api.nvim_get_option_value("statusline", { scope = "global" })
  local previous_local = vim.api.nvim_get_option_value("statusline", { win = winnr, scope = "local" })
  t:defer(function()
    vim.api.nvim_set_option_value("statusline", previous_global, { scope = "global" })
    vim.api.nvim_set_option_value("statusline", previous_local, { win = winnr, scope = "local" })
  end)

  local on_fulfilled = nil ---@type fun(result: string)|nil
  local value = "" ---@type string

  local dirtier = {} ---@type table

  function dirtier:is_dirty()
    return runtime.dirty
  end

  function dirtier:mark_clean()
    runtime.clean_count = runtime.clean_count + 1
    runtime.dirty = false
    for _, subscriber in ipairs(runtime.subscribers) do
      subscriber.on_next()
    end
  end

  function dirtier:subscribe(next_subscriber)
    runtime.subscribers[#runtime.subscribers + 1] = next_subscriber
    next_subscriber.on_next()
  end

  local nvimbar = {} ---@type table

  function nvimbar:place()
    return self
  end

  function nvimbar:refresh()
    runtime.refresh_count = runtime.refresh_count + 1
    return self
  end

  function nvimbar:snapshot()
    return value
  end

  ---@return boolean
  function nvimbar:isdisposed()
    return runtime.dispose_count > 0
  end

  ---@return nil
  function nvimbar:dispose()
    runtime.dispose_count = runtime.dispose_count + 1
  end

  runtime.fulfill = function(result)
    value = result
    assert(on_fulfilled)(result)
  end

  runtime.mark_dirty = function()
    runtime.dirty = true
    for _, subscriber in ipairs(runtime.subscribers) do
      subscriber.on_next()
    end
  end

  t:patch_global("stl", {
    c = {
      Subscriber = {
        new = function(props)
          return props
        end,
      },
    },
    fn = {
      falsy = function()
        return false
      end,
    },
    nvim = {
      fn = {
        augroup = function(name)
          local group = nvim_fn.augroup(name)
          if runtime.group == nil then
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
  t:patch_global("dot", {
    context = {
      flight = {
        devmode = {
          snapshot = function()
            return false
          end,
        },
      },
    },
    state = {
      status = {
        dirtier_statusline = dirtier,
      },
    },
  })
  t:patch_global("era", require("era"))
  t:patch_table(era.m, "nvimbar", {
    Nvimbar = {
      new = function(props)
        on_fulfilled = props.on_fulfilled
        return nvimbar
      end,
    },
    component = require("era.m.nvimbar").component,
  })
  t:patch_table(package.loaded, module_name, nil)

  t.assert_eq(module_name, era.dressing.__mods.statusline, "module registration")
  t.assert_nil(era.m.__mods.statusline, "old registration removed")
  local Statusline = era.dressing.statusline
  return runtime, Statusline
end

t:test("dressing requests initial data and publishes only completed results", function()
  local runtime, Statusline = setup()
  vim.o.statusline = "before"
  Statusline.dressing()
  t.assert_eq("before", vim.o.statusline, "no synchronous component refresh")
  t.assert_eq(1, runtime.refresh_count)
  t.assert_eq(1, runtime.clean_count)
  runtime.fulfill("initial")
  t.assert_eq("initial", vim.o.statusline)
  runtime.mark_dirty()
  t.assert_eq(2, runtime.refresh_count)
  t.assert_eq(2, runtime.clean_count, "consume dirty state when requesting, not when publishing")
  runtime.fulfill("updated")
  t.assert_eq("updated", vim.o.statusline)
  t.assert_eq(2, runtime.clean_count)
end)

t:test("partial publication cannot clear a newer dirty event", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  runtime.dirty = true
  runtime.fulfill("older partial result")
  t.assert_true(runtime.dirty)
  t.assert_eq(1, runtime.clean_count)
  runtime.mark_dirty()
  t.assert_eq(2, runtime.refresh_count)
end)

t:test("dressing subscribes once and preserves its mode callback", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  local autocmds = vim.api.nvim_get_autocmds({ group = runtime.group })
  t.assert_eq(2, #autocmds, "mode and exit callback count")

  Statusline.dressing()
  t.assert_eq(1, #runtime.subscribers, "dirty subscriptions")
  t.assert_eq(1, runtime.refresh_count, "initial render count")
  t.assert_eq(1, runtime.clean_count, "initial clean count")
  t.assert_true(
    vim.deep_equal(autocmds, vim.api.nvim_get_autocmds({ group = runtime.group })),
    "mode callback preserved"
  )

  runtime.mark_dirty()
  t.assert_eq(2, runtime.refresh_count, "one render per dirty update")
end)

t:test("repeated dressing preserves the latest statusline until the next refresh", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  runtime.fulfill("updated")

  Statusline.dressing()
  t.assert_eq("updated", vim.api.nvim_get_option_value("statusline", {}), "latest rendered statusline")
  t.assert_eq(1, runtime.refresh_count, "no repeated initial render")

  runtime.mark_dirty()
  runtime.fulfill("refreshed")
  t.assert_eq("refreshed", vim.api.nvim_get_option_value("statusline", {}), "later dirty refresh")
end)

t:test("mode changes request asynchronous refresh after the transition", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  for _, transition in ipairs({ "n:i", "n:c", "c:n" }) do
    vim.api.nvim_set_option_value("statusline", "stale", {})
    local count = runtime.refresh_count
    vim.api.nvim_exec_autocmds("ModeChanged", { group = runtime.group, pattern = transition, modeline = false })
    t.assert_eq(count, runtime.refresh_count, "event callback does not refresh inline")
    t.wait_until(function()
      return runtime.refresh_count == count + 1
    end, 1000)
    t.assert_eq("stale", vim.api.nvim_get_option_value("statusline", {}), "wait for the new snapshot")
    runtime.fulfill("updated " .. transition)
    t.assert_eq("updated " .. transition, vim.api.nvim_get_option_value("statusline", {}))
  end
end)

t:test("exit disposes once and ignores pending mode and dirty callbacks", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  local count = runtime.refresh_count
  vim.api.nvim_exec_autocmds("ModeChanged", { group = runtime.group, pattern = "n:c", modeline = false })
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = runtime.group, modeline = false })
  t.assert_eq(1, runtime.dispose_count)
  runtime.mark_dirty()
  local drained = false
  vim.schedule(function()
    drained = true
  end)
  t.wait_until(function()
    return drained
  end, 1000)
  t.assert_eq(count, runtime.refresh_count, "disposed statusline does not request more data")
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = runtime.group, modeline = false })
  t.assert_eq(1, runtime.dispose_count)
end)

t:test("unchanged publication skips option writes and still restores global ownership", function()
  local runtime = setup()
  vim.o.statusline = "before"
  local writes = 0
  local set_option = vim.api.nvim_set_option_value
  t:patch_table(vim.api, "nvim_set_option_value", function(name, value, opts)
    if name == "statusline" then
      writes = writes + 1
    end
    return set_option(name, value, opts)
  end)
  runtime.fulfill("stable")
  t.assert_eq(1, writes)
  runtime.fulfill("stable")
  t.assert_eq(1, writes, "unchanged output does not request another option update")

  set_option("statusline", "external", { scope = "global" })
  set_option("statusline", "stable", { scope = "local" })
  runtime.fulfill("stable")
  t.assert_eq(2, writes, "an equal local override must not hide the foreign global value")
  t.assert_eq("stable", vim.api.nvim_get_option_value("statusline", { scope = "global" }))
  t.assert_eq("", vim.api.nvim_get_option_value("statusline", { scope = "local" }))
end)

t:run()
