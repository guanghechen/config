---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("era.m.ui_attach.messages")

---@class era.m.ui_attach.messages.test.IRuntime
---@field deferred                      fun()[]
---@field reports                       { level: integer, options: table }[]
---@field transient                     string

---@return era.m.ui_attach.messages, era.m.ui_attach.messages.test.IRuntime
local function setup()
  local runtime = {
    deferred = {},
    reports = {},
    transient = "",
  } ---@type era.m.ui_attach.messages.test.IRuntime

  local msg_transient = {} ---@type table
  function msg_transient:next(value)
    runtime.transient = value
  end
  function msg_transient:snapshot()
    return runtime.transient
  end

  t:patch_global("dot", {
    state = {
      status = {
        msg_transient = msg_transient,
      },
    },
    var = {
      nsnr = {},
    },
  })
  t:patch_global("stl", {
    reporter = {
      log = function(level, options)
        runtime.reports[#runtime.reports + 1] = { level = level, options = options }
      end,
    },
  })
  t:patch_global("yoz", {
    fn = {
      md5 = function(value)
        return value
      end,
    },
  })
  t:patch_table(vim, "defer_fn", function(callback, timeout)
    t.assert_eq(3000, timeout, "transient timeout")
    runtime.deferred[#runtime.deferred + 1] = callback
  end)

  local messages = assert(loadfile("lua/era/m/ui_attach/messages.lua"))()
  return messages, runtime
end

---@param kind                          string
---@param message                       string
---@return era.m.ui_attach.ITask
local function create_task(kind, message)
  return {
    event = "msg_show",
    args = {
      kind,
      { { 0, message, 0 } },
      false,
      true,
    },
  }
end

t:test("progress is shown transiently without a popup", function()
  local messages, runtime = setup()

  messages.show(create_task("progress", '"test.json" 31L, 848B'))

  t.assert_eq('"test.json" 31L, 848B', runtime.transient, "statusline message")
  t.assert_eq(1, #runtime.deferred, "clear callback")
  t.assert_eq(1, #runtime.reports, "history report")
  t.assert_true(runtime.reports[1].options.silent, "silent report")
  t.assert_false(runtime.reports[1].options.anonymous, "history retention")
end)

t:test("a stale timeout does not clear a newer progress message", function()
  local messages, runtime = setup()

  messages.show(create_task("progress", "first"))
  messages.show(create_task("progress", "second"))

  runtime.deferred[1]()
  t.assert_eq("second", runtime.transient, "stale timeout")

  runtime.deferred[2]()
  t.assert_eq("", runtime.transient, "latest timeout")
end)

t:test("transient display normalizes control characters without changing history", function()
  local messages, runtime = setup()
  local message = "first\n\tsecond\rthird"

  messages.show(create_task("progress", message))

  t.assert_eq("first second third", runtime.transient, "statusline message")
  t.assert_eq(message, runtime.reports[1].options.message, "history message")
end)

t:test("ordinary info remains a popup", function()
  local messages, runtime = setup()

  messages.show(create_task("info", "important info"))

  t.assert_eq("", runtime.transient, "statusline message")
  t.assert_eq(0, #runtime.deferred, "clear callback")
  t.assert_eq(1, #runtime.reports, "notification report")
  t.assert_false(runtime.reports[1].options.silent, "visible report")
end)

t:run()
