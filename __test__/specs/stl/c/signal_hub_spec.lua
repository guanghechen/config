---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.stl.c.signal_hub" ---@type string

local harness = require("__test__.support.harness")
local SignalHub = require("stl.c.signal_hub")
local t = harness.new("stl.c.signal_hub")

---@return stl.c.SignalHub
---@return stl.c.signal_hub.IRole
---@return stl.c.signal_hub.IRole
---@return string
local function setup()
  local hub = SignalHub.new()
  t:defer(function()
    hub:dispose()
  end)
  return hub, hub:register_role("producer"), hub:register_role("consumer"), hub:register_signal("test.changed")
end

---@param callback                      fun(): any
---@param fragment                      string
---@return nil
local function rejects(callback, fragment)
  local ok, err = pcall(callback)
  t.assert_false(ok, "operation must fail")
  t.assert_true(tostring(err):find(fragment, 1, true) ~= nil, tostring(err))
end

---@param expected                      integer
---@param delivered                     integer
---@param errors                        ?stl.c.signal_hub.IDeliveryError[]
---@return nil
local function assert_delivery(expected, delivered, errors)
  if errors ~= nil then
    error("Unexpected callback failure: " .. tostring(errors[1].error), 2)
  end
  t.assert_eq(expected, delivered)
end

---@param signal                        string
---@param target                        ?stl.c.signal_hub.IRole
---@param scope                         ?string
---@param payload                       ?any
---@return stl.c.signal_hub.IEmission
local function emission(signal, target, scope, payload)
  return { signal = signal, scope = scope or "test", payload = payload, track = { to = target } }
end

t:test("core operates with only Lua standard globals", function()
  local environment = setmetatable({
    assert = assert,
    ipairs = ipairs,
    next = next,
    pairs = pairs,
    pcall = pcall,
    setmetatable = setmetatable,
    table = table,
    type = type,
  }, {
    __index = function(_, name)
      error("unexpected external dependency: " .. name)
    end,
  })
  local loader = assert(loadfile("lua/stl/c/signal_hub.lua"))
  setfenv(loader, environment)
  local isolated = loader().new() ---@type stl.c.SignalHub
  t:defer(function()
    isolated:dispose()
  end)
  local sender = isolated:register_role("sender")
  local receiver = isolated:register_role("receiver")
  local signal = isolated:register_signal("plain.changed")
  local called = false
  isolated:subscribe(receiver, { signal = signal }, function()
    called = true
  end)
  assert_delivery(1, isolated:emit(sender, emission(signal, receiver)))
  t.assert_true(called)
  isolated:unregister_role(receiver)
  isolated:unregister_signal(signal)
end)

t:test("stl exposes the class through its lazy module registry", function()
  local namespace = require("stl")
  t.assert_eq("stl.c.signal_hub", namespace.c.__mods.SignalHub)
  t.assert_eq(SignalHub, namespace.c.SignalHub)
end)

t:test("signal names are explicit and duplicate registration fails", function()
  local hub, sender, receiver, signal = setup()
  rejects(function()
    hub:register_signal(signal)
  end, "already registered")
  rejects(function()
    hub:register_signal("")
  end, "signal name")
  rejects(function()
    hub:emit(sender, emission("unknown"))
  end, "not registered")
  rejects(function()
    hub:subscribe(receiver, { signal = "unknown" }, function() end)
  end, "not registered")
end)

t:test("roles are identities even when diagnostic names are equal", function()
  local hub, sender, receiver, signal = setup()
  local other = hub:register_role(receiver.name)
  local selected = {}
  hub:subscribe(receiver, {}, function()
    selected[#selected + 1] = receiver
  end)
  hub:subscribe(other, {}, function()
    selected[#selected + 1] = other
  end)
  t.assert_true(receiver ~= other and receiver.id ~= other.id)
  assert_delivery(1, hub:emit(sender, emission(signal, other)))
  t.assert_eq(other, selected[1])
  rejects(function()
    hub:register_role("")
  end, "role name")
end)

t:test("fabricated and foreign identities cannot publish subscribe or receive", function()
  local hub, sender, receiver, signal = setup()
  local foreign = SignalHub.new()
  t:defer(function()
    foreign:dispose()
  end)
  local candidates = {
    { id = sender.id, name = sender.name },
    foreign:register_role(sender.name),
  }
  local received = 0
  hub:subscribe(receiver, {}, function()
    received = received + 1
  end)
  for _, invalid in ipairs(candidates) do
    rejects(function()
      hub:emit(invalid, emission(signal))
    end, "this hub")
    rejects(function()
      hub:emit(sender, emission(signal, invalid))
    end, "this hub")
    rejects(function()
      hub:subscribe(invalid, {}, function() end)
    end, "this hub")
    rejects(function()
      hub:unregister_role(invalid)
    end, "this hub")
  end
  t.assert_eq(0, received)
end)

t:test("delivery is synchronous and repeated notifications are not value-deduplicated", function()
  local hub, sender, receiver, signal = setup()
  local seen = {}
  hub:subscribe(receiver, {}, function(message)
    seen[#seen + 1] = message
  end)
  local input = emission(signal, receiver, nil, false)
  for i = 1, 3 do
    local delivered, errors = hub:emit(sender, input)
    t.assert_eq(1, delivered)
    t.assert_nil(errors)
    t.assert_eq(i, #seen)
    t.assert_eq(false, seen[i].payload)
  end
  t.assert_true(seen[1] ~= seen[2])
end)

t:test("routing combines signal scope and the receiving role", function()
  local hub, sender, receiver, signal = setup()
  local other_signal = hub:register_signal("test.other")
  local other_role = hub:register_role("other")
  local calls = {}
  local filters = {
    exact = { signal = signal, scope = "test" },
    signal = { signal = signal },
    scope = { scope = "test" },
    all = {},
    other_scope = { signal = signal, scope = "other" },
    other_signal = { signal = other_signal, scope = "test" },
  }
  for name, filter in pairs(filters) do
    hub:subscribe(receiver, filter, function()
      calls[name] = (calls[name] or 0) + 1
    end)
  end
  hub:subscribe(other_role, {}, function()
    calls.other_role = (calls.other_role or 0) + 1
  end)
  assert_delivery(4, hub:emit(sender, emission(signal, receiver)))
  t.assert_eq(1, calls.exact)
  t.assert_eq(1, calls.signal)
  t.assert_eq(1, calls.scope)
  t.assert_eq(1, calls.all)
  t.assert_nil(calls.other_scope)
  t.assert_nil(calls.other_signal)
  t.assert_nil(calls.other_role)
  assert_delivery(5, hub:emit(sender, emission(signal)))
  t.assert_eq(1, calls.other_role)
end)

t:test("filters are captured without retaining the caller's mutable declaration", function()
  local hub, sender, receiver, signal = setup()
  local filter = { signal = signal, scope = "test" }
  local calls = 0
  hub:subscribe(receiver, filter, function()
    calls = calls + 1
  end)
  filter.scope = "different"
  assert_delivery(1, hub:emit(sender, emission(signal, receiver)))
  assert_delivery(0, hub:emit(sender, emission(signal, receiver, "different")))
  t.assert_eq(1, calls)
end)

t:test("emission stamps tracking without mutating the caller's envelope or copying payload", function()
  local hub, sender, receiver, signal = setup()
  local payload = { text = "ready" }
  local input = emission(signal, receiver, nil, payload)
  local seen
  hub:subscribe(receiver, {}, function(message)
    seen = message
  end)
  hub:emit(sender, input)
  t.assert_true(seen ~= input and seen.track ~= input.track)
  t.assert_eq(payload, seen.payload)
  t.assert_eq(sender, seen.track.from)
  t.assert_eq(sender, seen.track.original)
  t.assert_eq(receiver, seen.track.to)
  t.assert_nil(rawget(assert(input.track), "from"))
  t.assert_nil(rawget(assert(input.track), "original"))
end)

t:test("forwarding preserves the original sender across multiple hops", function()
  local hub, sender, bridge, signal = setup()
  local destination = hub:register_role("destination")
  local captured
  hub:subscribe(bridge, {}, function(message)
    captured = message
  end)
  local final
  hub:subscribe(destination, { scope = "forwarded" }, function(message)
    final = message
  end)
  hub:emit(sender, emission(signal, bridge, nil, { text = "data" }))
  local initial = captured
  assert_delivery(1, hub:forward(bridge, initial, { to = destination, scope = "forwarded" }))
  t.assert_eq(bridge, final.track.from)
  t.assert_eq(sender, final.track.original)
  t.assert_eq(destination, final.track.to)
  t.assert_eq(initial.payload, final.payload)
  t.assert_eq("test", initial.scope)
  t.assert_eq(sender, initial.track.from)
  t.assert_eq(bridge, initial.track.to)

  assert_delivery(1, hub:forward(destination, final, { to = bridge }))
  t.assert_eq(destination, captured.track.from)
  t.assert_eq(sender, captured.track.original)
  t.assert_eq("forwarded", captured.scope)
end)

t:test("an empty forwarding destination broadcasts instead of retaining the old recipient", function()
  local hub, sender, bridge, signal = setup()
  local receiver = hub:register_role("receiver")
  local original
  hub:subscribe(bridge, { scope = "test" }, function(message)
    original = message
  end)
  hub:emit(sender, emission(signal, bridge))
  local received = 0
  for _, role in ipairs({ bridge, receiver }) do
    hub:subscribe(role, { scope = "broadcast" }, function(message)
      t.assert_nil(message.track.to)
      t.assert_eq(sender, message.track.original)
      received = received + 1
    end)
  end
  assert_delivery(2, hub:forward(bridge, original, { scope = "broadcast" }))
  t.assert_eq(2, received)
end)

t:test("historical senders remain traceable after unregistering", function()
  local hub, sender, bridge, signal = setup()
  local receiver = hub:register_role("receiver")
  local original, forwarded
  hub:subscribe(bridge, {}, function(message)
    original = message
  end)
  hub:subscribe(receiver, {}, function(message)
    forwarded = message
  end)
  hub:emit(sender, emission(signal, bridge))
  hub:unregister_role(sender)
  assert_delivery(1, hub:forward(bridge, original, { to = receiver }))
  t.assert_eq(sender, forwarded.track.original)
  t.assert_eq("producer", forwarded.track.original.name)
end)

t:test("invalid inputs do not create subscriptions or accidentally broadcast", function()
  local hub, sender, receiver, signal = setup()
  local delivered = 0
  hub:subscribe(receiver, {}, function()
    delivered = delivered + 1
  end)
  rejects(function()
    hub:subscribe(receiver, { scope = "" }, function() end)
  end, "scope")
  rejects(function()
    ---@diagnostic disable-next-line: param-type-mismatch
    hub:subscribe(receiver, {}, nil)
  end, "callback")
  local bad_target = { signal = signal, scope = "test", track = { to = false } } ---@type any
  rejects(function()
    hub:emit(sender, bad_target)
  end, "this hub")
  local bad_track = { signal = signal, scope = "test", track = false } ---@type any
  rejects(function()
    hub:emit(sender, bad_track)
  end, "track")
  rejects(function()
    hub:emit(sender, emission(signal, receiver, ""))
  end, "scope")
  t.assert_eq(0, delivered)
  assert_delivery(1, hub:emit(sender, emission(signal, receiver)))
end)

t:test("forwarding rejects invalid origins routes and scopes before delivery", function()
  local hub, sender, receiver, signal = setup()
  local captured
  hub:subscribe(receiver, {}, function(message)
    captured = message
  end)
  hub:emit(sender, emission(signal, receiver))
  local original = captured
  local route = { scope = false } ---@type any
  rejects(function()
    hub:forward(sender, original, route)
  end, "scope")
  route = { to = false }
  rejects(function()
    hub:forward(sender, original, route)
  end, "this hub")
  local bad = { signal = signal, scope = "test", track = { from = sender, original = {} } } ---@type any
  rejects(function()
    hub:forward(sender, bad, {})
  end, "this hub")
  t.assert_eq(original, captured)
end)

t:test("callback failures are returned while healthy subscriptions still receive the message", function()
  local hub, sender, receiver, signal = setup()
  local failure = { reason = "broken consumer" }
  local calls = 0
  hub:subscribe(receiver, {}, function()
    error(failure)
  end)
  hub:subscribe(receiver, {}, function()
    calls = calls + 1
  end)
  local delivered, errors = hub:emit(sender, emission(signal, receiver))
  t.assert_eq(1, delivered)
  t.assert_eq(1, calls)
  errors = assert(errors)
  t.assert_eq(1, #errors)
  t.assert_eq(receiver, errors[1].role)
  t.assert_eq(failure, errors[1].error)
end)

t:test("unsubscribe is idempotent and removes both directed and broadcast delivery", function()
  local hub, sender, receiver, signal = setup()
  local calls = 0
  local subscription = hub:subscribe(receiver, {}, function()
    calls = calls + 1
  end)
  subscription:unsubscribe()
  subscription:unsubscribe()
  assert_delivery(0, hub:emit(sender, emission(signal, receiver)))
  assert_delivery(0, hub:emit(sender, emission(signal)))
  t.assert_eq(0, calls)
end)

t:test("self-removal during delivery does not skip neighbouring subscriptions", function()
  local hub, sender, receiver, signal = setup()
  local order = {}
  local first
  first = hub:subscribe(receiver, {}, function()
    order[#order + 1] = "first"
    first:unsubscribe()
  end)
  hub:subscribe(receiver, {}, function()
    order[#order + 1] = "second"
  end)
  assert_delivery(2, hub:emit(sender, emission(signal)))
  assert_delivery(1, hub:emit(sender, emission(signal)))
  t.assert_eq("first,second,second", table.concat(order, ","))
end)

t:test("subscriptions removed before their turn do not run", function()
  local hub, sender, receiver, signal = setup()
  local next_subscription
  hub:subscribe(receiver, {}, function()
    next_subscription:unsubscribe()
  end)
  next_subscription = hub:subscribe(receiver, {}, function()
    error("removed callback ran")
  end)
  local delivered, errors = hub:emit(sender, emission(signal))
  t.assert_eq(1, delivered)
  t.assert_nil(errors)
end)

t:test("removing subscriptions preserves the order of survivors and later registrations", function()
  local hub, sender, receiver, signal = setup()
  local order = {}
  local subscriptions = {}
  for _, name in ipairs({ "a", "b", "c" }) do
    subscriptions[name] = hub:subscribe(receiver, {}, function()
      order[#order + 1] = name
    end)
  end
  subscriptions.b:unsubscribe()
  assert_delivery(2, hub:emit(sender, emission(signal)))
  t.assert_eq("a,c", table.concat(order, ","))
  subscriptions.c:unsubscribe()
  subscriptions.d = hub:subscribe(receiver, {}, function()
    order[#order + 1] = "d"
  end)
  order = {}
  assert_delivery(2, hub:emit(sender, emission(signal)))
  t.assert_eq("a,d", table.concat(order, ","))
  subscriptions.a:unsubscribe()
  subscriptions.d:unsubscribe()
  hub:subscribe(receiver, {}, function()
    order[#order + 1] = "e"
  end)
  order = {}
  assert_delivery(1, hub:emit(sender, emission(signal)))
  t.assert_eq("e", table.concat(order, ","))
end)

t:test("unregistering one role preserves peers sharing the same filter", function()
  local hub, sender, first, signal = setup()
  local removed = hub:register_role("removed")
  local last = hub:register_role("last")
  local order = {}
  for _, role in ipairs({ first, removed, last }) do
    hub:subscribe(role, { signal = signal, scope = "test" }, function()
      order[#order + 1] = role.name
    end)
  end
  hub:unregister_role(removed)
  assert_delivery(2, hub:emit(sender, emission(signal)))
  t.assert_eq("consumer,last", table.concat(order, ","))
  assert_delivery(1, hub:emit(sender, emission(signal, last)))
end)

t:test("removing and recreating scope buckets preserves peers and wildcard subscriptions", function()
  local hub, sender, receiver, signal = setup()
  local peer = hub:register_role("peer")
  local first = hub:subscribe(receiver, { signal = signal, scope = "count" }, function() end)
  local second = hub:subscribe(receiver, { signal = signal, scope = "count" }, function() end)
  local shared = hub:subscribe(peer, { signal = signal, scope = "count" }, function() end)
  local other = hub:subscribe(receiver, { signal = signal, scope = "buckets" }, function() end)
  local wildcard = hub:subscribe(receiver, { signal = signal }, function() end)

  first:unsubscribe()
  assert_delivery(2, hub:emit(sender, emission(signal, receiver, "count")))
  second:unsubscribe()
  assert_delivery(1, hub:emit(sender, emission(signal, receiver, "count")))
  assert_delivery(2, hub:emit(sender, emission(signal, nil, "count")))
  shared:unsubscribe()
  assert_delivery(1, hub:emit(sender, emission(signal, nil, "count")))

  local replacement = hub:subscribe(receiver, { signal = signal, scope = "count" }, function() end)
  assert_delivery(2, hub:emit(sender, emission(signal, receiver, "count")))
  assert_delivery(2, hub:emit(sender, emission(signal, receiver, "buckets")))
  replacement:unsubscribe()
  other:unsubscribe()
  wildcard:unsubscribe()
  hub:subscribe(receiver, { signal = signal, scope = "count" }, function() end)
  assert_delivery(1, hub:emit(sender, emission(signal, receiver, "count")))
  assert_delivery(1, hub:emit(sender, emission(signal, nil, "count")))
  assert_delivery(0, hub:emit(sender, emission(signal, nil, "buckets")))
end)

t:test("new subscriptions join the next emission even across filter buckets", function()
  local hub, sender, receiver, signal = setup()
  local added = false
  local calls = 0
  hub:subscribe(receiver, { signal = signal, scope = "test" }, function()
    if not added then
      added = true
      hub:subscribe(receiver, {}, function()
        calls = calls + 1
      end)
    end
  end)
  assert_delivery(1, hub:emit(sender, emission(signal)))
  t.assert_eq(0, calls)
  assert_delivery(2, hub:emit(sender, emission(signal)))
  t.assert_eq(1, calls)
end)

t:test("nested emissions have independent recipient snapshots", function()
  local hub, sender, receiver, signal = setup()
  local seen = {}
  hub:subscribe(receiver, {}, function(message)
    seen[#seen + 1] = message.payload
    if message.payload == "outer" then
      assert_delivery(2, hub:emit(receiver, emission(signal, receiver, nil, "inner")))
    end
  end)
  hub:subscribe(receiver, {}, function(message)
    seen[#seen + 1] = message.payload .. ":second"
  end)
  assert_delivery(2, hub:emit(sender, emission(signal, receiver, nil, "outer")))
  t.assert_eq("outer,inner,inner:second,outer:second", table.concat(seen, ","))
end)

t:test("unregistered roles cannot emit and late destinations never match a replacement", function()
  local hub, sender, receiver, signal = setup()
  hub:subscribe(receiver, {}, function()
    error("unregistered callback ran")
  end)
  hub:unregister_role(receiver)
  hub:unregister_role(receiver)
  local replacement = hub:register_role(receiver.name)
  local called = false
  hub:subscribe(replacement, {}, function()
    called = true
  end)
  t.assert_true(replacement.id > receiver.id)
  assert_delivery(0, hub:emit(sender, emission(signal, receiver)))
  t.assert_false(called)
  rejects(function()
    hub:emit(receiver, emission(signal))
  end, "unregistered")
  rejects(function()
    hub:subscribe(receiver, {}, function() end)
  end, "unregistered")
  assert_delivery(1, hub:emit(sender, emission(signal)))
end)

t:test("unregistering a receiver during dispatch stops its remaining callbacks", function()
  local hub, sender, receiver, signal = setup()
  hub:subscribe(receiver, {}, function()
    hub:unregister_role(receiver)
  end)
  hub:subscribe(receiver, {}, function()
    error("late callback ran")
  end)
  local delivered, errors = hub:emit(sender, emission(signal, receiver))
  t.assert_eq(1, delivered)
  t.assert_nil(errors)
end)

t:test("unregistering a signal removes exact subscriptions while wildcard subscriptions remain", function()
  local hub, sender, receiver, signal = setup()
  local other = hub:register_signal("test.other")
  local exact = hub:subscribe(receiver, { signal = signal }, function()
    error("old subscription ran")
  end)
  local count = 0
  hub:subscribe(receiver, {}, function()
    count = count + 1
  end)
  hub:unregister_signal(signal)
  exact:unsubscribe()
  rejects(function()
    hub:emit(sender, emission(signal))
  end, "not registered")
  assert_delivery(1, hub:emit(sender, emission(other)))
  hub:register_signal(signal)
  assert_delivery(1, hub:emit(sender, emission(signal)))
  t.assert_eq(2, count)
end)

t:test("re-registering a signal does not resume its previous in-flight broadcast", function()
  local hub, sender, receiver, signal = setup()
  hub:subscribe(receiver, { signal = signal }, function()
    hub:unregister_signal(signal)
    hub:register_signal(signal)
  end)
  local calls = 0
  hub:subscribe(receiver, {}, function()
    calls = calls + 1
  end)
  assert_delivery(1, hub:emit(sender, emission(signal)))
  t.assert_eq(0, calls)
  assert_delivery(1, hub:emit(sender, emission(signal)))
  t.assert_eq(1, calls)
end)

t:test("dispose interrupts delivery and leaves subscription cleanup idempotent", function()
  local hub, sender, receiver, signal = setup()
  local first = hub:subscribe(receiver, {}, function()
    hub:dispose()
  end)
  local second = hub:subscribe(receiver, {}, function()
    error("disposed callback ran")
  end)
  local delivered, errors = hub:emit(sender, emission(signal))
  t.assert_eq(1, delivered)
  t.assert_nil(errors)
  t.assert_true(hub:isdisposed())
  first:unsubscribe()
  second:unsubscribe()
  hub:dispose()
  rejects(function()
    hub:register_role("late")
  end, "disposed")
  rejects(function()
    hub:emit(sender, emission(signal))
  end, "disposed")
end)

t:test("unregistering releases callbacks and identities while the hub stays alive", function()
  local hub, sender, _, signal = setup()
  local weak = setmetatable({}, { __mode = "v" })
  local subscriptions = {}
  for i = 1, 100 do
    local owner = { index = i }
    local role = hub:register_role("temporary")
    weak[#weak + 1] = owner
    weak[#weak + 1] = role
    subscriptions[#subscriptions + 1] = hub:subscribe(role, { signal = signal }, function()
      t.assert_true(owner.index > 0)
    end)
    hub:unregister_role(role)
  end
  collectgarbage("collect")
  collectgarbage("collect")
  t.assert_nil(next(weak), "hub and retained unsubscribe handles must release former owners")
  assert_delivery(0, hub:emit(sender, emission(signal)))
  for _, subscription in ipairs(subscriptions) do
    subscription:unsubscribe()
  end
end)

for _, operation in ipairs({ "unregister_role", "unregister_signal", "dispose" }) do
  t:test(operation .. " cleans 20000 different scopes within the CPU regression ceiling", function()
    local hub, sender, receiver, signal = setup()
    local subscriptions = {}
    local count = 20000
    for i = 1, count do
      subscriptions[i] = hub:subscribe(receiver, { signal = signal, scope = tostring(i) }, function()
        error("cleaned subscription ran")
      end)
    end

    collectgarbage("collect")
    collectgarbage("stop")
    t:defer(function()
      collectgarbage("restart")
    end)
    local started = os.clock()
    if operation == "unregister_role" then
      hub:unregister_role(receiver)
    elseif operation == "unregister_signal" then
      hub:unregister_signal(signal)
    else
      hub:dispose()
    end
    local elapsed_ms = (os.clock() - started) * 1e3
    collectgarbage("restart")
    io.write(string.format("BENCH signal-hub %s scopes=%d cpu=%.3fms\n", operation, count, elapsed_ms))
    t.assert_true(elapsed_ms < 100, "different-scope cleanup exceeded the 100 ms CPU regression ceiling")

    for _, subscription in ipairs(subscriptions) do
      subscription:unsubscribe()
    end
    if operation == "dispose" then
      t.assert_true(hub:isdisposed())
    else
      if operation == "unregister_signal" then
        hub:register_signal(signal)
      end
      for i = 1, count do
        assert_delivery(0, hub:emit(sender, emission(signal, nil, tostring(i))))
      end
      local replacement = operation == "unregister_role" and hub:register_role("replacement") or receiver
      hub:subscribe(replacement, { signal = signal, scope = "1" }, function() end)
      assert_delivery(1, hub:emit(sender, emission(signal, replacement, "1")))
      assert_delivery(1, hub:emit(sender, emission(signal, nil, "1")))
    end
  end)
end

t:run()
