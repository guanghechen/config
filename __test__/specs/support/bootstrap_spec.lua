local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new()

t:test("with_native exposes the installed library and raises reporter errors", function()
  local native = bootstrap.with_native(t)
  t.assert_true(rawequal(native, yoz) and type(native.fuzzy) == "table", "native library global")
  t.assert_error(function()
    stl.reporter.error({ message = "reported" })
  end, "reported", "reporter errors raise")
end)

t:test("with_reporter records reports by level instead of raising", function()
  bootstrap.with_native(t)
  local reports = bootstrap.with_reporter(t)
  stl.reporter.error({ message = "first" })
  stl.reporter.warn({ message = "second" })
  t.assert_same({ { message = "first" } }, reports.error)
  t.assert_same({ { message = "second" } }, reports.warn)
end)

t:test("with_schedule queues callbacks until drained, including those queued while draining", function()
  local original = vim.schedule
  local ran = {} ---@type string[]
  local inner = harness.new()
  inner:test("case", function()
    local schedule = bootstrap.with_schedule(inner)
    vim.schedule(function()
      ran[#ran + 1] = "first"
      vim.schedule(function()
        ran[#ran + 1] = "nested"
      end)
    end)
    t.assert_same({}, ran, "queued, not run")
    t.assert_eq(1, #schedule.callbacks)
    schedule.drain()
    t.assert_same({ "first", "nested" }, ran)
  end)
  t.assert_eq(1, inner:run({ exit = false, quiet = true }).passed)
  t.assert_true(rawequal(original, vim.schedule), "vim.schedule restored after the case")
end)

t:test("with_autocmds records each event's callback instead of creating the autocommand", function()
  local callbacks = bootstrap.with_autocmds(t)
  local before = #vim.api.nvim_get_autocmds({ event = "User" })
  local seen = {} ---@type string[]
  vim.api.nvim_create_autocmd({ "User", "BufEnter" }, {
    callback = function(args)
      seen[#seen + 1] = args.event
    end,
  })
  t.assert_eq(before, #vim.api.nvim_get_autocmds({ event = "User" }), "no autocommand was created")
  callbacks.User({ event = "User" })
  callbacks.BufEnter({ event = "BufEnter" })
  t.assert_same({ "User", "BufEnter" }, seen)
end)

t:run()
