--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/ui_attach/init_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local module_name = "era.dressing.ui_attach"
local t = harness.new(module_name .. ".init")

---@class era.dressing.ui_attach.init.test.IRuntime
---@field callback                       fun(event: string, ...): boolean|nil
---@field module                         era.dressing.ui_attach
---@field enabled                        boolean
---@field attach_calls                   integer
---@field keymap_calls                   integer
---@field timer_calls                    integer
---@field timer_available                boolean
---@field errors                         table[]
---@field events                         string[]
---@field fail_id                        integer|nil
---@field fast                           boolean
---@field escape                         fun(): string
---@field hunk_nav_clears                integer
---@field search_clears                  integer
---@field searching                      boolean
---@field timer                          table

---@param initially_enabled              ?boolean
---@return era.dressing.ui_attach.init.test.IRuntime
local function setup(initially_enabled)
  local runtime = {
    enabled = initially_enabled ~= false,
    attach_calls = 0,
    keymap_calls = 0,
    timer_calls = 0,
    timer_available = true,
    errors = {},
    events = {},
    fast = false,
    hunk_nav_clears = 0,
    search_clears = 0,
    searching = false,
    timer = {},
  } ---@type era.dressing.ui_attach.init.test.IRuntime

  function runtime.timer:stop() end
  function runtime.timer:start(_, _, callback)
    self.callback = callback
  end

  local CircularQueue = require("stl.c.circular_queue")
  t:patch_global("dot", {
    context = {
      flight = {
        dressing_ui_attach = {
          snapshot = function()
            return runtime.enabled
          end,
        },
        devmode = {
          snapshot = function()
            return false
          end,
        },
      },
    },
    state = {
      status = {
        searching = {
          snapshot = function()
            return runtime.searching
          end,
          next = function(_, value)
            runtime.searching = value
          end,
        },
        clear_search = function()
          runtime.search_clears = runtime.search_clears + 1
        end,
      },
    },
    var = { nsnr = { attach = 1 } },
  })
  t:patch_global("stl", {
    c = { CircularQueue = CircularQueue },
    debug = { log_silent = function() end },
    nvim = {
      fn = {
        make_keys = function(_, lhs, callback)
          runtime.keymap_calls = runtime.keymap_calls + 1
          if lhs == "<esc>" then
            runtime.escape = callback
          end
        end,
      },
    },
    reporter = {
      error = function(options)
        runtime.errors[#runtime.errors + 1] = options
      end,
      warn = function() end,
    },
  })

  local function record(task)
    local id = task.args[6]
    if runtime.fail_id ~= nil and runtime.fail_id == id then
      error("handler failure")
    end
    runtime.events[#runtime.events + 1] = string.format("%s:%s", task.event, tostring(id or task.args[1]))
  end
  t:patch_table(package.loaded, "era.dressing.ui_attach.cmdline", {
    block_append = record,
    block_hide = record,
    block_show = record,
    hide = record,
    pos = record,
    show = record,
    special_char = record,
  })
  t:patch_table(package.loaded, "era.dressing.ui_attach.messages", {
    clear = record,
    history_show = record,
    ruler = record,
    show = record,
    showcmd = record,
    showmode = record,
  })
  t:patch_table(package.loaded, "era.dressing.ui_attach.popupmenu", {
    hide = record,
    select = record,
    show = record,
  })
  t:patch_table(package.loaded, "era.m.git.hunk_nav", {
    clear_nav = function()
      runtime.hunk_nav_clears = runtime.hunk_nav_clears + 1
    end,
  })

  t:patch_table(vim.uv, "new_timer", function()
    runtime.timer_calls = runtime.timer_calls + 1
    return runtime.timer_available and runtime.timer or nil
  end)
  t:patch_table(vim, "in_fast_event", function()
    return runtime.fast
  end)
  t:patch_table(vim, "schedule_wrap", function(callback)
    return callback
  end)
  t:patch_table(vim, "schedule", function(callback)
    callback()
  end)
  t:patch_table(vim, "ui_attach", function(_, _, callback)
    runtime.attach_calls = runtime.attach_calls + 1
    runtime.callback = callback
  end)

  t:patch_global("era", require("era"))
  t:patch_table(package.loaded, module_name, nil)
  t.assert_eq(module_name, era.dressing.__mods.ui_attach, "module registration")
  t.assert_nil(era.m.__mods.ui_attach, "old registration removed")
  runtime.module = era.dressing.ui_attach
  runtime.module.dressing()
  return runtime
end

t:test("dressing attaches once and preserves queued UI events and the escape binding", function()
  local runtime = setup()
  local callback = runtime.callback
  local escape = runtime.escape
  runtime.fast = true
  runtime.callback("msg_show", "echo", {}, false, false, false, 1, "")

  runtime.module.dressing()
  t.assert_eq(1, runtime.timer_calls, "timer allocation count")
  t.assert_eq(1, runtime.attach_calls, "UI attachment count")
  t.assert_eq(1, runtime.keymap_calls, "escape binding count")
  t.assert_eq(callback, runtime.callback, "UI callback preserved")
  t.assert_eq(escape, runtime.escape, "escape callback preserved")

  runtime.callback("msg_show", "echo", {}, false, false, false, 2, "")
  runtime.timer.callback()
  t.assert_true(vim.deep_equal({ "msg_show:1", "msg_show:2" }, runtime.events), "pending events remain ordered")

  runtime.enabled = false
  runtime.module.dressing()
  runtime.enabled = true
  runtime.module.dressing()
  t.assert_eq(1, runtime.timer_calls, "timer reused after repeated setup")
  t.assert_eq(1, runtime.attach_calls, "attachment reused after repeated setup")
  t.assert_eq(1, runtime.keymap_calls, "escape binding reused after repeated setup")
end)

t:test("skipped setup can retry after enabling and timer allocation recovers", function()
  local runtime = setup(false)
  runtime.module.dressing()
  t.assert_eq(0, runtime.timer_calls, "disabled setup does not allocate a timer")
  t.assert_eq(0, runtime.attach_calls, "disabled setup does not attach")
  t.assert_eq(0, runtime.keymap_calls, "disabled setup does not bind keys")

  runtime.enabled = true
  runtime.timer_available = false
  runtime.module.dressing()
  t.assert_eq(1, runtime.timer_calls, "failed allocation attempt")
  t.assert_eq(0, runtime.attach_calls, "allocation failure does not attach")
  t.assert_eq(0, runtime.keymap_calls, "allocation failure does not bind keys")

  runtime.timer_available = true
  runtime.module.dressing()
  runtime.module.dressing()
  t.assert_eq(2, runtime.timer_calls, "allocation retried once")
  t.assert_eq(1, runtime.attach_calls, "successful retry attaches once")
  t.assert_eq(1, runtime.keymap_calls, "successful retry binds keys once")
end)

t:test("fast event queue is lossless and ordered", function()
  local runtime = setup()
  runtime.fast = true

  for id = 1, 600 do
    runtime.callback("msg_show", "echo", {}, false, false, false, id, "")
  end
  runtime.timer.callback()

  t.assert_eq(600, #runtime.events, "event count")
  t.assert_eq("msg_show:1", runtime.events[1], "first event")
  t.assert_eq("msg_show:600", runtime.events[600], "last event")
end)

t:test("escape clears search state together with hlsearch", function()
  local runtime = setup()
  runtime.searching = true

  local key = runtime.escape()

  t.assert_eq("<esc>", key, "mapped key")
  t.assert_false(runtime.searching, "searching state")
  t.assert_eq(1, runtime.hunk_nav_clears, "hunk navigation clear")
  t.assert_eq(1, runtime.search_clears, "search clear")
end)

t:test("escape clears hunk navigation without active search", function()
  local runtime = setup()

  local key = runtime.escape()

  t.assert_eq("<esc>", key, "mapped key")
  t.assert_eq(1, runtime.hunk_nav_clears, "hunk navigation clear")
  t.assert_eq(0, runtime.search_clears, "search remains inactive")
end)

t:test("cmdline hide and show remain distinct ordered events", function()
  local runtime = setup()
  runtime.fast = true

  runtime.callback("cmdline_hide", 1, true)
  runtime.callback("cmdline_show", {}, 0, ":", "", 0, 1, 0)
  runtime.timer.callback()

  t.assert_eq(0, #runtime.errors, runtime.errors[1] and runtime.errors[1].details.error or "handler errors")
  t.assert_eq(2, #runtime.events, "event count")
  t.assert_eq("cmdline_hide:1", runtime.events[1], "hide event")
  t.assert_eq("cmdline_show:1", runtime.events[2], "show event")
end)

t:test("handler failures are reported and later events continue", function()
  local runtime = setup()
  runtime.fail_id = 1

  runtime.callback("msg_show", "echo", {}, false, false, false, 1, "")
  runtime.callback("msg_show", "echo", {}, false, false, false, 2, "")

  t.assert_eq(1, #runtime.errors, "reported errors")
  t.assert_eq(module_name, runtime.errors[1].from, "diagnostic namespace")
  t.assert_eq("msg_show:2", runtime.events[1], "continued event")
end)

t:run()
