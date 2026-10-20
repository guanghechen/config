local UI = require("__test__.support.ui")
local t = require("__test__.support.harness").new()

---@return __test__.support.UI
local function child()
  local ui = UI.new()
  t:defer(function()
    ui:close()
  end)
  return ui
end

t:test("a predicate that makes RPC requests still times out", function()
  local ui = child()
  local start = vim.uv.hrtime()
  local ok, err = pcall(ui.wait_until, ui, function()
    return ui:lua("return false")
  end, 50, "remote condition")
  t.assert_false(ok, "unready remote condition")
  t.assert_true(tostring(err):find("remote condition within 50 ms", 1, true) ~= nil, tostring(err))
  t.assert_true((vim.uv.hrtime() - start) / 1e6 < 2000, "responsive RPC cannot prevent the polling deadline")
end)

t:test("polling stops when the remote condition becomes true", function()
  local ui = child()
  ui:wait_until(function()
    return ui:lua("poll_count = (poll_count or 0) + 1; return poll_count == 3")
  end, 1000)
  t.assert_eq(3, ui:lua("return poll_count"), "no further polling after success")
end)

t:test("notifications reach the child and start prepares the checkout runtime", function()
  local ui = child()
  ui:notify("nvim_set_var", "notified", 1)
  ui:start({ width = 40, height = 10, runtime = "native" })
  t.assert_eq(1, ui:lua("return vim.g.notified"))
  t.wait_until(function()
    return ui.redraws > 0
  end, 5000, "attached UI receives redraws")
  t.assert_true(ui:lua("return type(yoz.fuzzy) == 'table' and stl.c.Future ~= nil and reports ~= nil"))
end)

t:run()
