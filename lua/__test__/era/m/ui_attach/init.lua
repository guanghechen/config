---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("era.m.ui_attach")

---@class era.m.ui_attach.init.test.IRuntime
---@field callback                       fun(event: string, ...): boolean|nil
---@field errors                         table[]
---@field events                         string[]
---@field fail_id                        integer|nil
---@field fast                           boolean
---@field escape                         fun(): string
---@field search_clears                  integer
---@field searching                      boolean
---@field timer                          table

---@return era.m.ui_attach.init.test.IRuntime
local function setup()
  local runtime = {
    errors = {},
    events = {},
    fast = false,
    search_clears = 0,
    searching = false,
    timer = {},
  } ---@type era.m.ui_attach.init.test.IRuntime

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
            return true
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
  t:patch_table(package.loaded, "era.m.ui_attach.cmdline", {
    block_append = record,
    block_hide = record,
    block_show = record,
    hide = record,
    pos = record,
    show = record,
    special_char = record,
  })
  t:patch_table(package.loaded, "era.m.ui_attach.messages", {
    clear = record,
    history_show = record,
    ruler = record,
    show = record,
    showcmd = record,
    showmode = record,
  })
  t:patch_table(package.loaded, "era.m.ui_attach.popupmenu", {
    hide = record,
    select = record,
    show = record,
  })

  t:patch_table(vim.uv, "new_timer", function()
    return runtime.timer
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
    runtime.callback = callback
  end)

  assert(loadfile("lua/era/m/ui_attach/init.lua"))().dressing()
  return runtime
end

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
  t.assert_eq(1, runtime.search_clears, "search clear")
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
  t.assert_eq("msg_show:2", runtime.events[1], "continued event")
end)

t:run()
