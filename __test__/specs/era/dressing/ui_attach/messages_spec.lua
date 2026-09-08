--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/ui_attach/messages_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.ui_attach.messages")

---@class era.dressing.ui_attach.messages.test.IRuntime
---@field deferred                      fun()[]
---@field errors                        table[]
---@field fail_message                  string|nil
---@field flush                         fun(): nil
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

---@return era.dressing.ui_attach.messages, era.dressing.ui_attach.messages.test.IRuntime
local function setup()
  local runtime = {
    deferred = {},
    errors = {},
    fail_message = nil,
    flush = function() end,
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
  } ---@type era.dressing.ui_attach.messages.test.IRuntime

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
      N_WINLINE_DISABLED = "ui_attach_messages_test_winline_disabled",
      nsnr = { attach = vim.api.nvim_create_namespace("era.dressing.ui_attach.messages.test") },
      zindex = { MESSAGES = 100 },
    },
  })
  t:patch_global("stl", {
    debug = {
      log_silent = function() end,
    },
    e = require("stl.e"),
    filetype = require("stl.filetype"),
    reporter = {
      dismiss = function(group)
        runtime.dismissed[#runtime.dismissed + 1] = group
      end,
      error = function(options)
        runtime.errors[#runtime.errors + 1] = options
      end,
      log = function(level, options)
        if options.message == runtime.fail_message then
          error("report failure")
        end
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

  local states = require("era.dressing.ui_attach.state")
  t:patch_table(states, "message", {
    generation = 0,
    groups = {},
    id_refs = {},
  })

  local messages = assert(loadfile("lua/era/dressing/ui_attach/messages.lua"))()
  runtime.flush = messages.flush
  return messages, runtime
end

local next_task_id = 0

---@param runtime                       era.dressing.ui_attach.messages.test.IRuntime
---@return nil
local function run_scheduled(runtime)
  runtime.flush()
  while #runtime.scheduled > 0 do
    local callback = table.remove(runtime.scheduled, 1)
    callback()
  end
end

---@param kind                          string
---@param message                       string
---@param opts                          { append: boolean?, history: boolean?, id: integer|string?, replace_last: boolean? }|nil
---@return era.dressing.ui_attach.ITask
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
  run_scheduled(runtime)

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
  run_scheduled(runtime)

  runtime.deferred[1]()
  t.assert_eq("second", runtime.transient, "stale timeout")

  runtime.deferred[2]()
  t.assert_eq("", runtime.transient, "latest timeout")
end)

t:test("transient display normalizes control characters without changing history", function()
  local messages, runtime = setup()
  local message = "first\n\tsecond\rthird"

  messages.show(create_task("progress", message))
  run_scheduled(runtime)

  t.assert_eq("first second third", runtime.transient, "statusline message")
  t.assert_eq(message, runtime.reports[1].options.message, "history message")
end)

t:test("ordinary info remains a popup", function()
  local messages, runtime = setup()

  messages.show(create_task("info", "important info"))
  run_scheduled(runtime)

  t.assert_eq("", runtime.transient, "statusline message")
  t.assert_eq(0, #runtime.deferred, "clear callback")
  t.assert_eq(1, #runtime.reports, "notification report")
  t.assert_false(runtime.reports[1].options.silent, "visible report")
end)

t:test("same message id updates one notifier group", function()
  local messages, runtime = setup()

  messages.show(create_task("echomsg", "first", { id = 7 }))
  run_scheduled(runtime)
  messages.show(create_task("echomsg", "second", { id = 7 }))
  run_scheduled(runtime)

  t.assert_eq(2, #runtime.reports, "report count")
  t.assert_eq(runtime.reports[1].options.group, runtime.reports[2].options.group, "stable group")
  t.assert_eq("second", runtime.reports[2].options.message, "updated message")
end)

t:test("coalesced updates retain explicit message history", function()
  local messages, runtime = setup()

  messages.show(create_task("echomsg", "first", { history = true, id = 7 }))
  messages.show(create_task("echomsg", "second", { history = false, id = 7 }))
  run_scheduled(runtime)

  t.assert_eq(1, #runtime.reports, "report count")
  t.assert_eq("second", runtime.reports[1].options.message, "latest message")
  t.assert_false(runtime.reports[1].options.anonymous, "history retention")
end)

t:test("coalesced updates retain history implied by earlier message kinds", function()
  local messages, runtime = setup()

  messages.show(create_task("progress", "progress", { history = false, id = 7 }))
  messages.show(create_task("info", "after progress", { history = false, id = 7 }))
  messages.show(create_task("echo", "echo", { history = false, id = 8 }))
  messages.show(create_task("info", "after echo", { history = false, id = 8 }))
  run_scheduled(runtime)

  t.assert_eq(2, #runtime.reports, "report count")
  t.assert_eq("after progress", runtime.reports[1].options.message, "transient group snapshot")
  t.assert_false(runtime.reports[1].options.anonymous, "transient history retention")
  t.assert_eq("after echo", runtime.reports[2].options.message, "echo group snapshot")
  t.assert_false(runtime.reports[2].options.anonymous, "echo history retention")
end)

t:test("append combines message ids and preserves later updates", function()
  local messages, runtime = setup()
  local states = require("era.dressing.ui_attach.state")

  messages.show(create_task("echo", "A", { id = 1 }))
  messages.show(create_task("echo", "B", { append = true, id = 2 }))
  messages.show(create_task("echo", "C", { id = 2 }))
  t.assert_eq(0, #runtime.reports, "reports before batch flush")
  run_scheduled(runtime)

  t.assert_eq(1, #runtime.reports, "coalesced report count")
  t.assert_eq(states.message.id_refs[1].group, states.message.id_refs[2].group, "append group")
  t.assert_eq(states.message.id_refs[1].group, runtime.reports[1].options.group, "reported group")
  t.assert_eq("AC", runtime.reports[1].options.message, "updated appended part")
end)

t:test("large append bursts render once per batch", function()
  local messages, runtime = setup()

  for id = 1, 1000 do
    messages.show(create_task("echo", "x", { append = id > 1, id = id }))
  end
  run_scheduled(runtime)

  t.assert_eq(1, #runtime.reports, "report count")
  t.assert_eq(1000, #runtime.reports[1].options.message, "message length")
end)

t:test("replace_last reuses the previous notifier group", function()
  local messages, runtime = setup()

  messages.show(create_task("echo", "first", { id = 1 }))
  run_scheduled(runtime)
  messages.show(create_task("echo", "second", { id = 2, replace_last = true }))
  run_scheduled(runtime)

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
  run_scheduled(runtime)

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

t:test("msg_clear silently retains pending history before dismissing groups", function()
  local messages, runtime = setup()
  local states = require("era.dressing.ui_attach.state")

  messages.show(create_task("info", "retained", { history = true, id = 1 }))
  local group = states.message.id_refs[1].group
  messages.clear({ event = "msg_clear", args = {} })
  run_scheduled(runtime)

  t.assert_eq(1, #runtime.reports, "report count")
  t.assert_eq("retained", runtime.reports[1].options.message, "history snapshot")
  t.assert_true(runtime.reports[1].options.silent, "hidden notification")
  t.assert_false(runtime.reports[1].options.anonymous, "history retention")
  t.assert_eq(group, runtime.reports[1].options.group, "reported group")
  t.assert_eq(group, runtime.dismissed[1], "dismissed group")
end)

t:test("msg_clear discards pending anonymous reports", function()
  local messages, runtime = setup()

  messages.show(create_task("info", "ephemeral", { history = false, id = 1 }))
  messages.clear({ event = "msg_clear", args = {} })
  run_scheduled(runtime)

  t.assert_eq(0, #runtime.reports, "report count")
  t.assert_eq(1, #runtime.dismissed, "dismissed group count")
end)

t:test("message history renders multiline and appended entries", function()
  local messages = setup()
  local states = require("era.dressing.ui_attach.state")
  local ranges = {} ---@type table[]

  t:patch_table(vim.fn, "synIDattr", function(hlid)
    return "Group" .. hlid
  end)
  t:patch_table(vim.hl, "range", function(_, _, hlname, from, to)
    ranges[#ranges + 1] = { hlname = hlname, from = from, to = to }
  end)
  t:defer(function()
    local winnr = states.message.history_winnr
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
    local bufnr = states.message.history_bufnr
    if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  messages.history_show({
    event = "msg_history_show",
    args = {
      {
        { "echo", { { 0, "first\n", 11 }, { 0, "second", 12 } }, false },
        { "echo", { { 0, " + tail\nlast", 13 } }, true },
        { "echo", { { 0, "文x", 14 } }, false },
      },
      false,
    },
  })

  local bufnr = states.message.history_bufnr
  t.assert_true(bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr), "history buffer")
  t.assert_true(
    vim.deep_equal({ "first", "second + tail", "last", "文x" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)),
    "history lines"
  )
  t.assert_true(
    vim.deep_equal({
      { hlname = "Group11", from = { 0, 0 }, to = { 0, 5 } },
      { hlname = "Group12", from = { 1, 0 }, to = { 1, 6 } },
      { hlname = "Group13", from = { 1, 6 }, to = { 1, 13 } },
      { hlname = "Group13", from = { 2, 0 }, to = { 2, 4 } },
      { hlname = "Group14", from = { 3, 0 }, to = { 3, 4 } },
    }, ranges),
    "history highlights"
  )
end)

t:test("one failed report does not abort later groups", function()
  local messages, runtime = setup()
  runtime.fail_message = "failure"

  messages.show(create_task("echo", "failure", { id = 1 }))
  messages.show(create_task("echo", "success", { id = 2 }))
  run_scheduled(runtime)

  t.assert_eq(1, #runtime.errors, "reported errors")
  t.assert_eq(1, #runtime.reports, "successful reports")
  t.assert_eq("success", runtime.reports[1].options.message, "continued group")
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
  local states = require("era.dressing.ui_attach.state")

  messages.show(create_task("emsg", "failure", { id = 1 }))
  run_scheduled(runtime)

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
