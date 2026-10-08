---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.treeview.recovery" ---@type string

local t = require("__test__.support.harness").new("ux.treeview.recovery")
local bootstrap = require("__test__.support.bootstrap")
local suffix = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
bootstrap.with_yoz(t, assert(package.loadlib("rust/target/debug/libyoz." .. suffix, "luaopen_yoz"))())
local Future = require("stl.c.future")
bootstrap.with_stl(t, {
  c = { Future = Future },
  nvim = { fn = require("stl.nvim.fn") },
  reporter = {
    error = function(options)
      error(options.message)
    end,
  },
})
local treeview = require("ux.treeview")

---@param future                        stl.c.Future
---@return any
local function await(future)
  t.wait_until(function()
    return future:is_done()
  end, 5000)
  t.assert_false(future:is_failed(), future:get_error())
  local result = future:get_result()
  t.assert_false(type(result) == "table" and result.kind == "Rejected", vim.inspect(result))
  return result
end

---@param prepare_frame                 ?function
---@return ux.treeview.Data, ux.treeview.View, table
local function fixture(prepare_frame)
  local data = treeview.new_data()
  await(data:import({
    { key = "root", label = "root", can_expand = true },
    { key = "a", parent = "root", label = "alpha" },
    { key = "b", parent = "root", label = "beta" },
  }))
  local state = await(data:create_state({ kind = "children_of", node = data:source():id("root") }))
  local errors = {}
  local view = treeview.attach(state, {
    keymaps = false,
    prepare_frame = prepare_frame,
    on_error = function(error)
      errors[#errors + 1] = error
    end,
  })
  t:defer(function()
    view:detach()
  end)
  t.wait_until(function()
    return view:frame() ~= nil and not view:status().preparing
  end, 5000)
  return data, view, errors
end

---@param view                          ux.treeview.View
---@param count                         integer
---@return fun(): integer
local function fail_writes(view, count)
  local set_lines = vim.api.nvim_buf_set_lines
  local failures = 0
  t:patch_table(vim.api, "nvim_buf_set_lines", function(bufnr, ...)
    if bufnr == view.bufnr and failures < count then
      failures = failures + 1
      error("injected publication failure")
    end
    return set_lines(bufnr, ...)
  end)
  return function()
    return failures
  end
end

t:test("temporary frame preparation does not consume automatic recovery", function()
  local deferred = 0
  local data, view, errors = fixture(function(current)
    if current:status().desynced and deferred == 0 then
      deferred = deferred + 1
      return Future.resolve(false)
    end
    return Future.resolve(function() end)
  end)
  local failures = fail_writes(view, 1)
  await(data:batch({ { kind = "update", node = "a", label = "changed" } }))
  t.wait_until(function()
    return deferred == 1
  end, 5000)
  t.wait_until(function()
    return view:frame() ~= nil and view:frame():node(data:source():id("a")).label == "changed"
  end, 1000, "temporarily unavailable preparation must retry without manual refresh")
  t.assert_eq(1, failures())
  t.assert_eq(1, #errors)
end)

t:test("a superseded recovery plan retries the latest topology", function()
  local complete, held
  local data, view, errors = fixture(function(current)
    if current:status().desynced and not held then
      held = true
      return Future.new(function(resolve)
        complete = resolve
      end)
    end
    return Future.resolve(function() end)
  end)
  fail_writes(view, 1)
  await(data:batch({ { kind = "update", node = "a", label = "changed" } }))
  t.wait_until(function()
    return complete ~= nil
  end, 5000)
  await(data:batch({ { kind = "insert", key = "c", parent = "root", label = "gamma" } }))
  t.wait_until(function()
    return view._state:snapshot():header().row_count == 3
  end, 5000)
  complete(function()
    error("superseded preparation must not commit")
  end)
  t.wait_until(function()
    return view:frame() ~= nil and view:frame():header().row_count == 3
  end, 1000, "a stale recovery plan must release its attempt for the latest frame")
  t.assert_eq("changed", view:frame():node(data:source():id("a")).label)
  t.assert_eq(1, #errors)
end)

t:test("a second actual publication failure waits for explicit refresh", function()
  local data, view, errors = fixture()
  local failures = fail_writes(view, 2)
  await(data:batch({ { kind = "update", node = "a", label = "changed" } }))
  t.wait_until(function()
    return failures() == 2 and view:status().desynced and not view:status().preparing
  end, 5000)
  for _ = 1, 3 do
    view:_poll()
  end
  t.assert_eq(2, #errors)
  view:refresh()
  t.wait_until(function()
    return view:frame() ~= nil and view:frame():node(data:source():id("a")).label == "changed"
  end, 5000)
  t.assert_eq(2, #errors)
end)

t:test("a projection failure suspends automatic recovery until refresh", function()
  local data, view = fixture()
  local calls, poll = 0, data._poll
  t:patch_table(data, "_poll", function(self)
    calls = calls + 1
    return poll(self)
  end)
  local snapshot = view:frame()
  view._latest = snapshot
  local restore_view = t:patch_table(view, "_native", {
    poll_frame = function()
      return nil, { code = "ProviderError", message = "projection unavailable" }
    end,
    snapshot = function()
      return snapshot
    end,
  })
  local restore_state = t:patch_table(view._state, "_native", {
    applicable = function()
      return false
    end,
  })
  require("ux.treeview.surface").fail(view, "injected publication failure", true)
  require("ux.treeview.async").watch(data)
  t.wait_until(function()
    return view._projection_error ~= nil
  end, 1000)
  vim.wait(100, function()
    return false
  end, 20)
  local settled = calls
  vim.wait(150, function()
    return false
  end, 20)
  t.assert_eq(settled, calls, "a terminal projection error must not keep the owner polling")
  restore_view()
  restore_state()
  view:refresh()
  t.wait_until(function()
    return view:frame() ~= nil and not view._projection_error and not view:status().preparing
  end, 1000)
end)

t:run()
