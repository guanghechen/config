--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/ui_attach/messages_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("era.m.ui_attach.messages")

---@class era.m.ui_attach.messages.test.IRuntime
---@field deferred                      fun()[]
---@field reports                       { level: integer, options: table }[]
---@field scheduled                     fun()[]
---@field transient                     string
---@field command                       string
---@field mode                          string
---@field dismissed                     string[]
---@field dirtied                       integer
---@field search                        { bufnr: integer, count: string|nil, pattern: string, winnr: integer }|nil
---@field search_pattern                string
---@field searching_updates             integer

---@return era.m.ui_attach.messages, era.m.ui_attach.messages.test.IRuntime
local function setup()
  local runtime = {
    deferred = {},
    reports = {},
    scheduled = {},
    transient = "",
    command = "",
    mode = "",
    dismissed = {},
    dirtied = 0,
    search = nil,
    search_pattern = "foo",
    searching_updates = 0,
  } ---@type era.m.ui_attach.messages.test.IRuntime

  local msg_transient = {} ---@type table
  function msg_transient:next(value)
    runtime.transient = value
  end
  function msg_transient:snapshot()
    return runtime.transient
  end

  local msg_command = {} ---@type table
  function msg_command:next(value)
    runtime.command = value
  end

  local msg_mode = {} ---@type table
  function msg_mode:next(value)
    runtime.mode = value
  end

  local searching = {} ---@type table
  function searching:next()
    runtime.searching_updates = runtime.searching_updates + 1
  end

  t:patch_global("dot", {
    state = {
      status = {
        msg_transient = msg_transient,
        msg_command = msg_command,
        msg_mode = msg_mode,
        searching = searching,
        set_search = function(winnr, bufnr, pattern, count)
          runtime.search = { winnr = winnr, bufnr = bufnr, pattern = pattern, count = count }
        end,
        dirtier_statusline = {
          mark_dirty = function()
            runtime.dirtied = runtime.dirtied + 1
          end,
        },
      },
    },
    var = {
      nsnr = {},
    },
  })
  t:patch_global("stl", {
    reporter = {
      dismiss = function(group)
        runtime.dismissed[#runtime.dismissed + 1] = group
      end,
      log = function(level, options)
        runtime.reports[#runtime.reports + 1] = { level = level, options = options }
      end,
    },
  })
  t:patch_table(vim, "defer_fn", function(callback, timeout)
    t.assert_eq(3000, timeout, "transient timeout")
    runtime.deferred[#runtime.deferred + 1] = callback
  end)
  t:patch_table(vim, "schedule", function(callback)
    runtime.scheduled[#runtime.scheduled + 1] = callback
  end)
  t:patch_table(vim.fn, "getreg", function(register)
    t.assert_eq("/", register, "search register")
    return runtime.search_pattern
  end)

  local states = require("era.m.ui_attach.state")
  t:patch_table(states, "message", {
    generation = 0,
    groups = {},
    id_refs = {},
  })

  local messages = assert(loadfile("lua/era/m/ui_attach/messages.lua"))()
  return messages, runtime
end

local next_task_id = 0

---@param runtime                       era.m.ui_attach.messages.test.IRuntime
---@return nil
local function run_scheduled(runtime)
  while #runtime.scheduled > 0 do
    local callback = table.remove(runtime.scheduled, 1)
    callback()
  end
end

---@param kind                          string
---@param message                       string
---@param opts                          { append: boolean?, history: boolean?, id: integer|string?, replace_last: boolean? }|nil
---@return era.m.ui_attach.ITask
local function create_task(kind, message, opts)
  opts = opts or {}
  local id = opts.id ---@type integer|string|nil
  if id == nil then
    next_task_id = next_task_id + 1
    id = next_task_id
  end
  return {
    event = "msg_show",
    args = {
      kind,
      { { 0, message, 0 } },
      opts.replace_last == true,
      opts.history ~= false,
      opts.append == true,
      id,
      "",
    },
  }
end

t:test("progress is shown transiently without a popup", function()
  local messages, runtime = setup()

  messages.show(create_task("progress", '"test.json" 31L, 848B'))

  t.assert_eq('"test.json" 31L, 848B', runtime.transient, "statusline message")
  t.assert_eq(1, #runtime.deferred, "clear callback")
  t.assert_eq(1, #runtime.reports, "history report")
  t.assert_eq(1, runtime.dirtied, "statusline refresh")
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

t:test("same message id updates one notifier group", function()
  local messages, runtime = setup()

  messages.show(create_task("echomsg", "first", { id = 7 }))
  messages.show(create_task("echomsg", "second", { id = 7 }))

  t.assert_eq(2, #runtime.reports, "report count")
  t.assert_eq(runtime.reports[1].options.group, runtime.reports[2].options.group, "stable group")
  t.assert_eq("second", runtime.reports[2].options.message, "updated message")
end)

t:test("append combines message ids and preserves later updates", function()
  local messages, runtime = setup()

  messages.show(create_task("echo", "A", { id = 1 }))
  messages.show(create_task("echo", "B", { append = true, id = 2 }))
  messages.show(create_task("echo", "C", { id = 2 }))

  t.assert_eq(runtime.reports[1].options.group, runtime.reports[2].options.group, "append group")
  t.assert_eq(runtime.reports[2].options.group, runtime.reports[3].options.group, "update group")
  t.assert_eq("AB", runtime.reports[2].options.message, "appended message")
  t.assert_eq("AC", runtime.reports[3].options.message, "updated appended part")
end)

t:test("replace_last reuses the previous notifier group", function()
  local messages, runtime = setup()

  messages.show(create_task("echo", "first", { id = 1 }))
  messages.show(create_task("echo", "second", { id = 2, replace_last = true }))

  t.assert_eq(runtime.reports[1].options.group, runtime.reports[2].options.group, "replacement group")
  t.assert_eq("second", runtime.reports[2].options.message, "replacement message")
end)

t:test("empty in a non-empty batch preserves visible messages", function()
  local messages, runtime = setup()

  messages.show(create_task("echo", "A", { id = 1 }))
  messages.show({
    event = "msg_show",
    args = { "empty", {}, false, false, false, -1, "" },
  })
  run_scheduled(runtime)

  t.assert_eq(1, #runtime.reports, "report count")
  t.assert_eq(0, #runtime.dismissed, "dismissed groups")
  t.assert_eq(0, runtime.searching_updates, "search state")
end)

t:test("standalone empty clears visible message state", function()
  local messages, runtime = setup()

  messages.show(create_task("echo", "A", { id = 1 }))
  run_scheduled(runtime)
  messages.show({
    event = "msg_show",
    args = { "empty", {}, false, false, false, -1, "" },
  })
  run_scheduled(runtime)
  messages.show(create_task("echo", "B", { append = true, id = 1 }))

  t.assert_eq(2, #runtime.reports, "report count")
  t.assert_eq("B", runtime.reports[2].options.message, "post-clear append")
  t.assert_false(runtime.reports[1].options.group == runtime.reports[2].options.group, "new group")
  t.assert_eq(runtime.reports[1].options.group, runtime.dismissed[1], "dismissed group")
end)

t:test("msg_clear resets transient state without changing search state", function()
  local messages, runtime = setup()
  runtime.transient = "stale"

  messages.clear({ event = "msg_clear", args = {} })

  t.assert_eq("", runtime.transient, "transient state")
  t.assert_eq(0, runtime.searching_updates, "search state")
end)

t:test("search count publishes window-scoped winline state", function()
  local messages, runtime = setup()

  messages.show(create_task("search_count", " /foo            [2/10] "))

  t.assert_eq(1, runtime.searching_updates, "search state")
  t.assert_eq(vim.api.nvim_get_current_win(), runtime.search.winnr, "search window")
  t.assert_eq(vim.api.nvim_get_current_buf(), runtime.search.bufnr, "search buffer")
  t.assert_eq("foo", runtime.search.pattern, "search pattern")
  t.assert_eq("2/10", runtime.search.count, "search count")
end)

t:test("count-only navigation keeps the current search pattern", function()
  local messages, runtime = setup()

  messages.show(create_task("search_count", " [3/10] "))

  t.assert_eq("foo", runtime.search.pattern, "search pattern")
  t.assert_eq("3/10", runtime.search.count, "search count")
end)

t:test("a new search command replaces the pattern and clears the previous count", function()
  local messages, runtime = setup()
  runtime.search = { winnr = 1, bufnr = 1, pattern = "foo", count = "2/10" }
  runtime.search_pattern = "next"

  messages.show(create_task("search_cmd", "/next"))

  t.assert_eq(1, runtime.searching_updates, "search state")
  t.assert_eq("next", runtime.search.pattern, "new pattern")
  t.assert_nil(runtime.search.count, "stale search count")
end)

t:test("emsg is reported as an error instead of waiting for a prompt", function()
  local messages, runtime = setup()
  local states = require("era.m.ui_attach.state")

  messages.show(create_task("emsg", "failure", { id = 1 }))

  t.assert_eq(1, #runtime.reports, "error report")
  t.assert_eq(vim.log.levels.ERROR, runtime.reports[1].level, "error level")
  t.assert_nil(states.message.confirming_task, "confirm state")
end)

t:test("empty showcmd clears the statusline command", function()
  local messages, runtime = setup()
  runtime.command = "stale"

  messages.showcmd({ event = "msg_showcmd", args = { {} } })

  t.assert_eq("", runtime.command, "showcmd state")
  t.assert_eq(1, runtime.dirtied, "statusline refresh")
end)

t:test("showcmd and ruler keep independent state", function()
  local messages, runtime = setup()

  messages.ruler({ event = "msg_ruler", args = { { { 0, "2,1 All", 0 } } } })
  messages.showcmd({ event = "msg_showcmd", args = { { { 0, "d", 0 } } } })
  t.assert_eq("d  2,1 All", runtime.command, "combined command state")

  messages.ruler({ event = "msg_ruler", args = {} })
  t.assert_eq("d", runtime.command, "showcmd after ruler clear")

  messages.ruler({ event = "msg_ruler", args = { { { 0, "2,1 All", 0 } } } })
  messages.showcmd({ event = "msg_showcmd", args = { {} } })
  t.assert_eq("2,1 All", runtime.command, "ruler after showcmd clear")

  messages.ruler({ event = "msg_ruler", args = { {} } })
  t.assert_eq("", runtime.command, "cleared command state")
end)

t:test("showmode marks the statusline dirty", function()
  local messages, runtime = setup()

  messages.showmode({ event = "msg_showmode", args = { { { 0, "-- INSERT --", 0 } } } })

  t.assert_eq("-- INSERT --", runtime.mode, "showmode state")
  t.assert_eq(1, runtime.dirtied, "statusline refresh")
end)

t:run()
