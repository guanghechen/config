---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.stl.c.subscribers" ---@type string

local t = require("__test__.support.harness").new("stl.c.subscribers")
require("__test__.support.bootstrap").with_stl(t, {
  fn = { noop = function() end },
  c = { BatchHandler = require("stl.c.batch_handler") },
})
local Subscribers = require("stl.c.subscribers")
local Subscriber = require("stl.c.subscriber")

---@param subscribers                   stl.c.Subscribers
---@return stl.c.IUnsubscribable, table
local function retained_callback(subscribers)
  local owner = { bytes = string.rep("x", 1024) }
  local weak = setmetatable({ owner }, { __mode = "v" })
  local subscriber = Subscriber.new({
    on_next = function()
      return owner.bytes
    end,
  })
  weak[2] = subscriber
  local subscription = subscribers:subscribe(subscriber)
  return subscription, weak
end

t:test("one unsubscribe releases the callback owner without requiring another subscription", function()
  local subscribers = Subscribers.new()
  local subscription, weak = retained_callback(subscribers)
  subscription:unsubscribe()
  subscription:unsubscribe()
  collectgarbage("collect")
  t.assert_nil(next(weak), "an inactive subscription retained its subscriber or callback owner")
  t.assert_eq(0, subscribers:count())
  subscribers:notify("after unsubscribe")
end)

t:test("unsubscribe does not dispose a subscriber shared by another publisher", function()
  local first, second = Subscribers.new(), Subscribers.new()
  local values, disposed = {}, 0
  local subscriber = Subscriber.new({
    on_next = function(value)
      values[#values + 1] = value
    end,
    on_dispose = function()
      disposed = disposed + 1
    end,
  })
  local subscription = first:subscribe(subscriber)
  second:subscribe(subscriber)
  subscription:unsubscribe()
  first:dispose()
  second:notify("still active")
  t.assert_true(vim.deep_equal({ "still active" }, values))
  t.assert_eq(0, disposed)
  second:dispose()
  t.assert_eq(1, disposed)
end)

t:test("unsubscribe and subscribe inside notification preserve delivery order", function()
  local subscribers = Subscribers.new({ ARRANGE_THRESHOLD = 1 })
  local first, second
  local delivered = {}
  first = subscribers:subscribe(Subscriber.new({
    on_next = function()
      delivered[#delivered + 1] = "first"
      first:unsubscribe()
      second:unsubscribe()
      subscribers:subscribe(Subscriber.new({
        on_next = function()
          delivered[#delivered + 1] = "later"
        end,
      }))
    end,
  }))
  second = subscribers:subscribe(Subscriber.new({
    on_next = function()
      delivered[#delivered + 1] = "second"
    end,
  }))
  subscribers:notify(1)
  t.assert_true(vim.deep_equal({ "first" }, delivered))
  subscribers:notify(2)
  t.assert_true(vim.deep_equal({ "first", "later" }, delivered))
  t.assert_eq(1, subscribers:count())
end)

t:test("publisher disposal releases callbacks even while unsubscribe handles are retained", function()
  local subscribers = Subscribers.new()
  local subscription, weak = retained_callback(subscribers)
  subscribers:dispose()
  collectgarbage("collect")
  t.assert_nil(next(weak))
  subscription:unsubscribe()
  t.assert_eq(0, subscribers:count())
end)

t:run()
