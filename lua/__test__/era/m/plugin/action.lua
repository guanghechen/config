---@diagnostic disable: undefined-global

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.plugin.action")
local Future = require("stl.c.future")

bootstrap.with_stl(t, {
  c = { Future = Future },
  reporter = {
    info = function() end,
    warn = function() end,
  },
  shell = {
    get_shell_args = function(command)
      return { "sh", "-c", command }
    end,
  },
})

local State = {
  options = { root = "/plugins" },
}
bootstrap.with_dot(t, {
  path = {
    join = function(...)
      return table.concat({ ... }, "/")
    end,
  },
})
t:patch_table(package.loaded, "era.m.plugin.state", State)

local Action = require("era.m.plugin.action")

local function reset_action()
  t:patch_table(Action, "_running", false)
  t:patch_table(Action, "_tasks", {})
  t:patch_table(Action, "_history", {})
end

t:test("string build resolves spawn failures", function()
  reset_action()
  t:patch_table(vim, "system", function()
    error("injected spawn failure", 0)
  end)

  local future = Action.__run_build__({ build = "cargo build --release" }, "/plugin")

  t.assert_true(future:is_resolved(), "spawn failure future")
  local result = future:get_result()
  t.assert_false(result.ok, "spawn failure result")
  t.assert_true(result.err:find("injected spawn failure", 1, true) ~= nil, "spawn failure diagnostic")
end)

t:test("build releases state after an unexpected rejection", function()
  reset_action()
  t:patch_table(package.loaded, "era.m.plugin.loader", {
    get = function()
      return { spec = { name = "blink.cmp", build = "cargo build --release" } }
    end,
  })
  t:patch_table(Action, "__run_build__", function()
    return Future.reject("unexpected build rejection")
  end)

  local progress_count = 0
  local future = Action.build("blink.cmp", function()
    progress_count = progress_count + 1
  end)

  t.assert_true(future:is_resolved(), "build should consume worker rejection")
  t.assert_false(Action.is_running(), "build lock")
  t.assert_eq("error", Action.get_tasks()["blink.cmp"].status, "task status")
  t.assert_true(
    Action.get_tasks()["blink.cmp"].message:find("unexpected build rejection", 1, true) ~= nil,
    "task diagnostic"
  )
  t.assert_eq("error", Action.get_history()["blink.cmp"].status, "history status")
  t.assert_eq(2, progress_count, "progress notifications")
end)

t:test("non-zero string build preserves the last streamed diagnostic", function()
  reset_action()
  t:patch_table(vim, "system", function(_, opts, callback)
    opts.stderr(nil, "first diagnostic\nblink-build-diagnostic\n")
    callback({ code = 1, stderr = nil })
    return {}
  end)

  local task = {}
  local future = Action.__run_build__({ build = "cargo build --release" }, "/plugin", task)
  t.wait_until(function()
    return future:is_done()
  end, 1000, "build callback")

  t.assert_true(future:is_resolved(), "non-zero future")
  local result = future:get_result()
  t.assert_false(result.ok, "non-zero result")
  t.assert_eq("blink-build-diagnostic", result.err, "final diagnostic")
  t.assert_eq(2, #task.output, "bounded output")
  t.assert_eq("blink-build-diagnostic", task.output[2], "streamed diagnostic")
end)

t:run()
