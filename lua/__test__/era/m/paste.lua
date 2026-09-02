---@diagnostic disable: undefined-global
--- Test for era.m.paste module
--- Run with: nvim -l lua/__test__/era/m/paste.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.paste")

---@class era.m.paste.test.ICall
---@field lines                         string[]
---@field phase                         integer

---@class era.m.paste.test.IRuntime
---@field events                        { event: string, opts: table }[]
---@field flush_idle                    fun()
---@field scheduled                     fun()[]

---@param opts                          { cmdtype: string?, modifiable: boolean?, mode: string?, paste_result: boolean? }|nil
---@return fun(lines: string[], phase: integer): boolean, era.m.paste.test.ICall[], era.m.paste, era.m.paste.test.IRuntime
local function setup(opts)
  opts = opts or {}
  local calls = {} ---@type era.m.paste.test.ICall[]
  local idle_callback = nil ---@type fun()|nil
  local idle_pending = false
  local runtime = {
    events = {},
    scheduled = {},
    flush_idle = function()
      if idle_pending and idle_callback ~= nil then
        idle_pending = false
        idle_callback()
      end
    end,
  } ---@type era.m.paste.test.IRuntime

  t:patch_global("stl", {
    timer = {
      debounce = function(callback)
        idle_callback = callback
        return setmetatable({
          cancel = function()
            idle_pending = false
          end,
          dispose = function()
            idle_pending = false
          end,
          stop = function()
            idle_pending = false
          end,
        }, {
          __call = function()
            idle_pending = true
          end,
        })
      end,
    },
  })
  t:patch_table(vim, "paste", function(lines, phase)
    calls[#calls + 1] = { lines = vim.deepcopy(lines), phase = phase }
    return opts.paste_result ~= false
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return opts.cmdtype or ""
  end)
  t:patch_table(vim, "schedule", function(callback)
    runtime.scheduled[#runtime.scheduled + 1] = callback
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_exec_autocmds", function(event, event_opts)
    runtime.events[#runtime.events + 1] = { event = event, opts = event_opts }
  end)
  t:patch_table(vim.api, "nvim_get_current_buf", function()
    return 11
  end)
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = opts.mode or "n" }
  end)
  t:patch_table(vim.api, "nvim_get_option_value", function(name)
    if name == "modifiable" then
      return opts.modifiable ~= false
    end
    error("unexpected option read: " .. name)
  end)

  local Paste = assert(loadfile("lua/era/m/paste.lua"))()
  Paste.dressing()
  ---@diagnostic disable-next-line: redundant-return-value
  return vim.paste, calls, Paste, runtime
end

t:test("joins streamed chunks and commits once", function()
  local paste, calls = setup()

  t.assert_true(paste({ "alpha", "be" }, 1), "start")
  t.assert_true(paste({ "ta", "gamma", "" }, 2), "continue")
  t.assert_true(paste({ "delta" }, 3), "end")

  t.assert_eq(1, #calls, "calls")
  t.assert_eq(-1, calls[1].phase, "phase")
  t.assert_true(vim.deep_equal({ "alpha", "beta", "gamma", "delta" }, calls[1].lines), "lines")
end)

t:test("preserves text across arbitrary chunk boundaries", function()
  local paste, calls = setup()
  local text = "alpha\nbeta\n\ngamma\n"

  for i = 1, #text do
    local phase = i == 1 and 1 or (i == #text and 3 or 2)
    local lines = vim.split(text:sub(i, i), "\n", { plain = true, trimempty = false })
    t.assert_true(paste(lines, phase), "chunk")
  end

  t.assert_eq(1, #calls, "calls")
  t.assert_eq(text, table.concat(calls[1].lines, "\n"), "text")
end)

t:test("new stream replaces abandoned buffered chunks", function()
  local paste, calls = setup()

  paste({ "stale" }, 1)
  paste({ "fresh", "" }, 1)
  paste({ "content" }, 3)

  t.assert_eq(1, #calls, "calls")
  t.assert_true(vim.deep_equal({ "fresh", "content" }, calls[1].lines), "lines")
end)

t:test("flushes bounded batches with streaming phases", function()
  local paste, calls = setup()
  local chunk = string.rep("x", 600 * 1024)

  t.assert_true(paste({ chunk }, 1), "start")
  t.assert_true(paste({ chunk }, 2), "flush")
  t.assert_true(paste({ "tail" }, 3), "end")

  t.assert_eq(2, #calls, "calls")
  t.assert_eq(1, calls[1].phase, "start phase")
  t.assert_eq(#chunk * 2, #calls[1].lines[1], "flushed bytes")
  t.assert_eq(3, calls[2].phase, "end phase")
  t.assert_true(vim.deep_equal({ "tail" }, calls[2].lines), "tail")
end)

t:test("propagates cancellation and releases buffered state", function()
  local paste, calls, _, runtime = setup({ paste_result = false })
  local chunk = string.rep("x", 1024 * 1024)

  t.assert_false(paste({ chunk }, 1), "cancelled flush")
  t.assert_false(paste({ "tail" }, 2), "continuation after cancellation")

  t.assert_eq(1, #calls, "calls")
  t.assert_eq(1, calls[1].phase, "start phase")
  t.assert_eq(0, #runtime.scheduled, "paste done callbacks")
end)

t:test("stops calling downstream after idle cancellation", function()
  local paste, calls, _, runtime = setup({ paste_result = false })

  t.assert_true(paste({ "alpha" }, 1), "buffered start")
  runtime.flush_idle()
  t.assert_eq(1, #calls, "idle calls")
  t.assert_eq(1, calls[1].phase, "idle phase")

  t.assert_false(paste({ "beta" }, 2), "cancelled continuation")
  t.assert_eq(1, #calls, "downstream calls after cancellation")
end)

t:test("emits one paste settled event after successful completion", function()
  local paste, _, _, runtime = setup()

  paste({ "alpha" }, 1)
  paste({ "beta" }, 3)

  t.assert_eq(1, #runtime.scheduled, "scheduled callbacks")
  runtime.scheduled[1]()
  t.assert_eq(1, #runtime.events, "events")
  t.assert_eq("User", runtime.events[1].event, "event")
  t.assert_eq("EraPasteSettled", runtime.events[1].opts.pattern, "pattern")
  t.assert_eq(11, runtime.events[1].opts.data.bufnr, "buffer")
end)

t:test("settles a stream when phase three is delayed", function()
  local paste, calls, _, runtime = setup()

  paste({ "alpha" }, 1)
  paste({ "beta" }, 2)
  t.assert_eq(0, #calls, "calls before idle")

  runtime.flush_idle()
  t.assert_eq(1, #calls, "calls after idle")
  t.assert_eq(1, calls[1].phase, "idle phase")
  t.assert_eq(1, #runtime.scheduled, "settled callbacks")

  paste({ "" }, 3)
  t.assert_eq(2, #calls, "calls after end")
  t.assert_eq(3, calls[2].phase, "end phase")
  t.assert_eq(1, #runtime.scheduled, "settled callbacks after end")
end)

t:test("ignores empty intermediate chunks", function()
  local paste, calls, _, runtime = setup()

  paste({ "" }, 1)
  runtime.flush_idle()
  t.assert_eq(0, #calls, "empty calls")

  paste({ "content" }, 2)
  runtime.flush_idle()
  t.assert_eq(1, #calls, "content calls")
  t.assert_eq(1, calls[1].phase, "content phase")
  t.assert_true(vim.deep_equal({ "content" }, calls[1].lines), "content")
end)

t:test("emits settled for each idle segment", function()
  local paste, _, _, runtime = setup()

  paste({ "alpha" }, 1)
  runtime.flush_idle()
  paste({ "beta" }, 2)
  runtime.flush_idle()

  t.assert_eq(2, #runtime.scheduled, "settled callbacks")
end)

t:test("passes non-streaming paste through unchanged", function()
  local paste, calls = setup()
  local lines = { "alpha", "beta" }

  paste(lines, -1)

  t.assert_eq(1, #calls, "calls")
  t.assert_eq(-1, calls[1].phase, "phase")
  t.assert_true(vim.deep_equal(lines, calls[1].lines), "lines")
end)

t:test("does not emit settled for empty non-streaming paste", function()
  local paste, _, _, runtime = setup()

  paste({ "" }, -1)

  t.assert_eq(0, #runtime.scheduled, "settled callbacks")
end)

t:test("buffers insert mode streams", function()
  local paste, calls = setup({ mode = "i" })

  paste({ "alpha" }, 1)
  paste({ "beta" }, 3)

  t.assert_eq(1, #calls, "calls")
  t.assert_eq(-1, calls[1].phase, "phase")
  t.assert_true(vim.deep_equal({ "alphabeta" }, calls[1].lines), "lines")
end)

t:test("passes terminal streams through unchanged", function()
  local paste, calls = setup({ mode = "t" })

  paste({ "alpha" }, 1)
  paste({ "beta" }, 2)
  paste({ "gamma" }, 3)

  t.assert_eq(3, #calls, "calls")
  t.assert_eq(1, calls[1].phase, "start phase")
  t.assert_eq(2, calls[2].phase, "continue phase")
  t.assert_eq(3, calls[3].phase, "end phase")
end)

t:test("passes cmdline and unmodifiable streams through", function()
  local paste_cmdline, cmdline_calls = setup({ cmdtype = ":" })
  paste_cmdline({ "cmd" }, 1)
  paste_cmdline({ "line" }, 3)

  t.assert_eq(2, #cmdline_calls, "cmdline calls")

  local paste_unmodifiable, unmodifiable_calls = setup({ modifiable = false })
  paste_unmodifiable({ "read" }, 1)
  paste_unmodifiable({ "only" }, 3)

  t.assert_eq(2, #unmodifiable_calls, "unmodifiable calls")
end)

t:test("passes replace mode streams through", function()
  local paste, calls = setup({ mode = "R" })

  paste({ "alpha" }, 1)
  paste({ "beta" }, 2)
  paste({ "gamma" }, 3)

  t.assert_eq(3, #calls, "calls")
  t.assert_eq(1, calls[1].phase, "start phase")
  t.assert_eq(2, calls[2].phase, "continue phase")
  t.assert_eq(3, calls[3].phase, "end phase")
end)

t:test("rewraps a later image handler around complete streamed text", function()
  local optimized_paste, calls, Paste = setup()
  local image_path = nil ---@type string|nil

  ---@diagnostic disable-next-line: duplicate-set-field
  vim.paste = function(lines, phase)
    if phase == -1 and #lines == 1 and lines[1]:match("%.png$") then
      image_path = lines[1]
      return true
    end
    return optimized_paste(lines, phase)
  end
  Paste.dressing()

  vim.paste({ "/tmp/screen" }, 1)
  vim.paste({ "shot.png" }, 3)

  t.assert_eq("/tmp/screenshot.png", image_path, "image path")
  t.assert_eq(0, #calls, "default calls")
end)

t:run()
