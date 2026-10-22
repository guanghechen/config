local harness = require("__test__.support.harness")

local t = harness.new()
local timer = require("stl.timer")

t:test("throttle reads a function window as each window starts", function()
  local calls, reads = {}, 0
  local throttled = timer.throttle(function(value)
    calls[#calls + 1] = { value = value, at = vim.uv.hrtime() }
  end, function()
    reads = reads + 1
    return reads == 1 and 30 or 120
  end)
  t:defer(function()
    throttled:dispose()
  end)

  throttled(1)
  throttled(2)
  throttled(3)
  t.wait_until(function()
    return #calls == 2
  end, 2000, "the latest call runs when the first window ends")
  t.assert_same({ 1, 3 }, { calls[1].value, calls[2].value })
  t.assert_true((calls[2].at - calls[1].at) / 1e6 >= 20, "the first window held the trailing call")

  throttled(4)
  t.wait_until(function()
    return #calls == 3
  end, 2000, "the next call waits for the second window")
  t.assert_true((calls[3].at - calls[2].at) / 1e6 >= 100, "the second window was read when it started")
  t.assert_eq(3, reads)
end)

t:run()
