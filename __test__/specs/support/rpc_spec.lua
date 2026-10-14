---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.support.rpc" ---@type string

local Rpc = require("__test__.support.rpc")
local t = require("__test__.support.harness").new(__module_name__)

t:test("a false RPC predicate times out and its child can be closed", function()
  local rpc = Rpc.new(assert(vim.uv.cwd()))
  t:defer(function()
    rpc:close()
  end)
  rpc:lua("return true")
  local start = vim.uv.hrtime()
  local ready = Rpc.wait(50, function()
    return rpc:lua("return false")
  end, 1)
  t.assert_false(ready, "unready remote condition")
  t.assert_true((vim.uv.hrtime() - start) / 1e6 < 2000, "responsive RPC cannot prevent the polling deadline")
  rpc:close()
  t.assert_true(rpc.exit_code ~= nil, "child exited after the timeout")
end)

t:test("RPC polling stops when the remote condition becomes true", function()
  local rpc = Rpc.new(assert(vim.uv.cwd()))
  t:defer(function()
    rpc:close()
  end)
  t.assert_true(
    Rpc.wait(1000, function()
      return rpc:lua("cmp_poll_count = (cmp_poll_count or 0) + 1; return cmp_poll_count == 3")
    end, 1),
    "remote condition became ready"
  )
  t.assert_eq(3, rpc:lua("return cmp_poll_count"), "no further polling after success")
end)

t:run()
