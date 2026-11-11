local dressing = require("__test__.support.dressing")
local harness = require("__test__.support.harness")

local t = harness.new()
local module_name = "era.dressing.statusline"
local EXPRESSION = "%!v:lua.require'era.dressing.statusline'.render()"

---@param message                       ?string
---@return string
local function displayed(message)
  t.assert_eq(EXPRESSION, vim.o.statusline, message or "statusline evaluates the cached text")
  return vim.api.nvim_eval_statusline(vim.o.statusline, {}).str
end

---@class era.dressing.statusline.test.IRuntime
---@field clean_count                  integer
---@field dirty                        boolean
---@field subscribers                  { on_next: fun() }[]
---@field augroups                     __test__.support.dressing.Augroups
---@field bar                          __test__.support.dressing.Bar
---@field mark_dirty                   fun()

---@return era.dressing.statusline.test.IRuntime, era.dressing.statusline
local function setup()
  local runtime = {
    clean_count = 0,
    dirty = true,
    subscribers = {},
    augroups = dressing.augroups(t),
  } ---@type era.dressing.statusline.test.IRuntime

  local winnr = vim.api.nvim_get_current_win()
  local previous_global = vim.api.nvim_get_option_value("statusline", { scope = "global" })
  local previous_local = vim.api.nvim_get_option_value("statusline", { win = winnr, scope = "local" })
  t:defer(function()
    vim.api.nvim_set_option_value("statusline", previous_global, { scope = "global" })
    vim.api.nvim_set_option_value("statusline", previous_local, { win = winnr, scope = "local" })
  end)

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

  local nvimbars = dressing.nvimbars()

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
        augroup = runtime.augroups.augroup,
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
    Nvimbar = nvimbars.Nvimbar,
    component = require("era.m.nvimbar").component,
  })
  t:patch_table(package.loaded, module_name, nil)

  t.assert_eq(module_name, era.dressing.__mods.statusline, "module registration")
  local Statusline = era.dressing.statusline
  runtime.bar = nvimbars.bars.statusline
  return runtime, Statusline
end

t:test("dressing requests initial data and publishes only completed results", function()
  local runtime, Statusline = setup()
  vim.o.statusline = "before"
  Statusline.dressing()
  t.assert_eq("before", vim.o.statusline, "no synchronous component refresh")
  t.assert_eq(1, runtime.bar.refreshes)
  t.assert_eq(1, runtime.clean_count)
  runtime.bar:fulfill("initial")
  t.assert_eq("initial", displayed())
  runtime.mark_dirty()
  t.assert_eq(2, runtime.bar.refreshes)
  t.assert_eq(2, runtime.clean_count, "consume dirty state when requesting, not when publishing")
  runtime.bar:fulfill("updated")
  t.assert_eq("updated", displayed())
  t.assert_eq(2, runtime.clean_count)
end)

t:test("partial publication cannot clear a newer dirty event", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  runtime.dirty = true
  runtime.bar:fulfill("older partial result")
  t.assert_true(runtime.dirty)
  t.assert_eq(1, runtime.clean_count)
  runtime.mark_dirty()
  t.assert_eq(2, runtime.bar.refreshes)
end)

t:test("dressing subscribes once and preserves its mode callback", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  local autocmds = vim.api.nvim_get_autocmds({ group = runtime.augroups.groups[module_name] })
  t.assert_eq(2, #autocmds, "mode and exit callback count")

  Statusline.dressing()
  t.assert_eq(1, #runtime.subscribers, "dirty subscriptions")
  t.assert_eq(1, runtime.bar.refreshes, "initial render count")
  t.assert_eq(1, runtime.clean_count, "initial clean count")
  t.assert_same(
    autocmds,
    vim.api.nvim_get_autocmds({ group = runtime.augroups.groups[module_name] }),
    "mode callback preserved"
  )

  runtime.mark_dirty()
  t.assert_eq(2, runtime.bar.refreshes, "one render per dirty update")
end)

t:test("repeated dressing preserves the latest statusline until the next refresh", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  runtime.bar:fulfill("updated")

  Statusline.dressing()
  t.assert_eq("updated", displayed("latest rendered statusline"))
  t.assert_eq(1, runtime.bar.refreshes, "no repeated initial render")

  runtime.mark_dirty()
  runtime.bar:fulfill("refreshed")
  t.assert_eq("refreshed", displayed("later dirty refresh"))
end)

t:test("mode changes request asynchronous refresh after the transition", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  for _, transition in ipairs({ "n:i", "n:c", "c:n" }) do
    vim.api.nvim_set_option_value("statusline", "stale", {})
    local count = runtime.bar.refreshes
    vim.api.nvim_exec_autocmds(
      "ModeChanged",
      { group = runtime.augroups.groups[module_name], pattern = transition, modeline = false }
    )
    t.assert_eq(count, runtime.bar.refreshes, "event callback does not refresh inline")
    t.wait_until(function()
      return runtime.bar.refreshes == count + 1
    end, 5000)
    t.assert_eq("stale", vim.api.nvim_get_option_value("statusline", {}), "wait for the new snapshot")
    runtime.bar:fulfill("updated " .. transition)
    t.assert_eq("updated " .. transition, displayed())
  end
end)

t:test("exit disposes once and ignores pending mode and dirty callbacks", function()
  local runtime, Statusline = setup()
  Statusline.dressing()
  local count = runtime.bar.refreshes
  vim.api.nvim_exec_autocmds(
    "ModeChanged",
    { group = runtime.augroups.groups[module_name], pattern = "n:c", modeline = false }
  )
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = runtime.augroups.groups[module_name], modeline = false })
  t.assert_eq(1, runtime.bar.disposals)
  runtime.mark_dirty()
  t.drain()
  t.assert_eq(count, runtime.bar.refreshes, "disposed statusline does not request more data")
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = runtime.augroups.groups[module_name], modeline = false })
  t.assert_eq(1, runtime.bar.disposals)
end)

t:test("content changes skip option writes and foreign values restore global ownership", function()
  local runtime, Statusline = setup()
  vim.o.statusline = "before"
  local writes = 0
  local set_option = vim.api.nvim_set_option_value
  t:patch_table(vim.api, "nvim_set_option_value", function(name, value, opts)
    if name == "statusline" then
      writes = writes + 1
    end
    return set_option(name, value, opts)
  end)
  runtime.bar:fulfill("stable")
  t.assert_eq(1, writes)
  runtime.bar:fulfill("stable")
  t.assert_eq(1, writes, "unchanged output does not request another option update")
  runtime.bar:fulfill("changed")
  t.assert_eq(1, writes, "a literal write would recompose the focused floating window")
  t.assert_eq("changed", Statusline.render())
  t.assert_eq("changed", displayed())

  set_option("statusline", "external", { scope = "global" })
  set_option("statusline", EXPRESSION, { scope = "local" })
  runtime.bar:fulfill("changed")
  t.assert_eq(2, writes, "an equal local override must not hide the foreign global value")
  t.assert_eq(EXPRESSION, vim.api.nvim_get_option_value("statusline", { scope = "global" }))
  t.assert_eq("", vim.api.nvim_get_option_value("statusline", { scope = "local" }))
end)

t:test("content changes redraw only the status line", function()
  local runtime = setup()
  vim.o.statusline = "before"
  local redraws = {} ---@type vim.api.keyset.redraw[]
  local commands = {} ---@type string[]
  local redraw = vim.api.nvim__redraw
  t:patch_table(vim.api, "nvim__redraw", function(opts)
    redraws[#redraws + 1] = opts
    return redraw(opts)
  end)
  t:patch_table(vim, "cmd", function(command)
    commands[#commands + 1] = command
  end)

  runtime.bar:fulfill("stable")
  runtime.bar:fulfill("changed")
  runtime.bar:fulfill("changed")

  t.assert_eq(1, #redraws, "redraws per changed text")
  t.assert_same(
    { win = vim.api.nvim_get_current_win(), statusline = true },
    redraws[1],
    "status line redraw of the current window"
  )
  t.assert_eq(0, #commands, "command redraws")
  t.assert_eq("changed", displayed())
end)

t:run()
