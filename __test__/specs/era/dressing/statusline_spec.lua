--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/statusline_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.dressing.statusline module

local harness = require("__test__.support.harness")
local nvim_fn = require("stl.nvim.fn")

local t = harness.new("era.dressing.statusline")
local module_name = "era.dressing.statusline"

---@class era.dressing.statusline.test.IRuntime
---@field clean_count                  integer
---@field dirty                        boolean
---@field renders                      boolean[]
---@field subscribers                  { on_next: fun() }[]
---@field group                        ?integer
---@field fulfill                      fun(result: string)
---@field mark_dirty                   fun()

---@return era.dressing.statusline.test.IRuntime, era.dressing.statusline
local function setup()
  local runtime = {
    clean_count = 0,
    dirty = true,
    renders = {},
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

  function nvimbar:render(immediate)
    runtime.renders[#runtime.renders + 1] = immediate == true
    if immediate then
      value = "initial"
    end
    return value
  end

  function nvimbar:snapshot()
    return value
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

  local component = setmetatable({}, {
    __index = function(_, group)
      return setmetatable({}, {
        __index = function(_, name)
          return function()
            return group .. "." .. name
          end
        end,
      })
    end,
  })

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
    component = component,
  })
  t:patch_table(package.loaded, module_name, nil)

  t.assert_eq(module_name, era.dressing.__mods.statusline, "module registration")
  t.assert_nil(era.m.__mods.statusline, "old registration removed")
  local Statusline = era.dressing.statusline
  return runtime, Statusline
end

t:test("dressing renders once immediately and preserves dirty updates", function()
  local runtime, Statusline = setup()

  vim.o.statusline = ""
  Statusline.dressing()

  t.assert_eq("initial", vim.o.statusline, "initial statusline")
  t.assert_eq(1, #runtime.renders, "initial render count")
  t.assert_true(runtime.renders[1], "initial render mode")
  t.assert_eq(1, runtime.clean_count, "initial clean count")

  runtime.mark_dirty()
  t.assert_eq(2, #runtime.renders, "dirty render count")
  t.assert_false(runtime.renders[2], "dirty render mode")

  runtime.fulfill("updated")
  t.assert_eq("updated", vim.o.statusline, "updated statusline")
  t.assert_eq(2, runtime.clean_count, "fulfilled clean count")
end)

t:test("dressing subscribes once and preserves its mode callback", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  local autocmds = vim.api.nvim_get_autocmds({ group = runtime.group })
  t.assert_eq(1, #autocmds, "mode callback count")

  Statusline.dressing()
  t.assert_eq(1, #runtime.subscribers, "dirty subscriptions")
  t.assert_eq(1, #runtime.renders, "initial render count")
  t.assert_eq(1, runtime.clean_count, "initial clean count")
  t.assert_true(
    vim.deep_equal(autocmds, vim.api.nvim_get_autocmds({ group = runtime.group })),
    "mode callback preserved"
  )

  runtime.mark_dirty()
  t.assert_eq(2, #runtime.renders, "one render per dirty update")
end)

t:test("repeated dressing preserves the latest statusline until the next refresh", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  runtime.fulfill("updated")

  Statusline.dressing()
  t.assert_eq("updated", vim.api.nvim_get_option_value("statusline", {}), "latest rendered statusline")
  t.assert_eq(1, #runtime.renders, "no repeated initial render")

  runtime.mark_dirty()
  runtime.fulfill("refreshed")
  t.assert_eq("refreshed", vim.api.nvim_get_option_value("statusline", {}), "later dirty refresh")
end)

t:test("mode changes keep command-line transitions immediately visible", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  vim.api.nvim_exec_autocmds("ModeChanged", { group = runtime.group, pattern = "n:i", modeline = false })
  t.assert_eq(2, #runtime.renders, "normal mode refresh count")
  t.assert_false(runtime.renders[2], "normal mode refresh is scheduled")

  for _, transition in ipairs({ "n:c", "c:n" }) do
    vim.api.nvim_set_option_value("statusline", "stale", {})
    local render_count = #runtime.renders
    vim.api.nvim_exec_autocmds("ModeChanged", { group = runtime.group, pattern = transition, modeline = false })
    t.wait_until(function()
      return #runtime.renders == render_count + 2
    end, 1000, "command-line transition renders immediately")
    t.assert_false(runtime.renders[render_count + 1], "scheduled mode refresh")
    t.assert_true(runtime.renders[render_count + 2], "immediate command-line refresh")
    t.assert_eq("initial", vim.api.nvim_get_option_value("statusline", {}), "visible command-line refresh")
  end
end)

t:run()
