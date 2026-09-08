--- Run from the repository root with the LUA_PATH documented in spec/design/signal-hub.md.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.signal_hub" ---@type string

local SignalHub = require("stl.c.signal_hub")
local iterations = tonumber(arg[1]) or 50000
local rounds = 7
assert(iterations > 0 and iterations % 1 == 0, "Expected a positive iteration count")

---@param samples                       number[]
---@return number
---@return number
local function summarize(samples)
  table.sort(samples)
  return samples[math.ceil(#samples / 2)], samples[#samples]
end

---@param name                          string
---@param unrelated                     integer
---@param fanout                        integer
---@param targeted                      boolean
---@return nil
local function measure_delivery(name, unrelated, fanout, targeted)
  local hub = SignalHub.new()
  local signal = hub:register_signal("bench.changed")
  local noise = hub:register_signal("bench.noise")
  local sender = hub:register_role("sender")
  local receiver = hub:register_role("receiver")
  local calls = 0
  for _ = 1, fanout do
    hub:subscribe(receiver, { signal = signal, scope = "main" }, function()
      calls = calls + 1
    end)
  end
  for i = 1, unrelated do
    local role = hub:register_role("unrelated")
    hub:subscribe(role, {
      signal = i % 2 == 0 and signal or noise,
      scope = i % 2 == 0 and "other" or "main",
    }, function()
      error("Unrelated subscriber received a message")
    end)
  end
  local request = {
    signal = signal,
    scope = "main",
    payload = { value = 1 },
    track = { to = targeted and receiver or nil },
  }
  local samples = {}
  local count = math.max(1000, math.floor(iterations / fanout))
  for round = 0, rounds do
    collectgarbage("collect")
    local before = calls
    local started = os.clock()
    for _ = 1, count do
      local delivered, errors = hub:emit(sender, request)
      assert(delivered == fanout and errors == nil, "Delivery failed")
    end
    local elapsed = os.clock() - started
    assert(calls - before == count * fanout, "Callback count mismatch")
    if round > 0 then
      samples[#samples + 1] = elapsed * 1e6 / count
    end
  end
  hub:dispose()
  local median, maximum = summarize(samples)
  io.write(string.format("%s,%d,%d,%.3f,%.3f\n", name, unrelated, fanout, median, maximum))
end

---@param count                         integer
---@param operation                     "unregister_role"|"unregister_signal"|"dispose"
---@param role_count                    integer
---@param scope_count                   integer
---@return nil
local function measure_cleanup(count, operation, role_count, scope_count)
  local samples = {}
  for round = 0, rounds do
    local hub = SignalHub.new()
    local signal = hub:register_signal("bench.cleanup")
    local roles = {}
    for i = 1, role_count do
      roles[i] = hub:register_role("temporary")
    end
    for i = 1, count do
      local role = roles[(i - 1) % role_count + 1]
      local scope = "scope." .. ((i - 1) % scope_count + 1)
      hub:subscribe(role, { signal = signal, scope = scope }, function() end)
    end
    collectgarbage("collect")
    local started = os.clock()
    if operation == "unregister_role" then
      for _, role in ipairs(roles) do
        hub:unregister_role(role)
      end
    elseif operation == "unregister_signal" then
      hub:unregister_signal(signal)
    else
      hub:dispose()
    end
    if round > 0 then
      samples[#samples + 1] = (os.clock() - started) * 1e3
    end
    hub:dispose()
  end
  local median, maximum = summarize(samples)
  io.write(string.format("%s,%d,%d,%d,%.3f,%.3f\n", operation, count, role_count, scope_count, median, maximum))
end

io.write("scenario,unrelated_subscriptions,callbacks_per_emit,median_batch_us_per_emit,max_batch_us_per_emit\n")
measure_delivery("directed", 0, 1, true)
measure_delivery("directed", 1000, 1, true)
measure_delivery("directed", 10000, 1, true)
measure_delivery("broadcast", 0, 1, false)
measure_delivery("broadcast", 1000, 1, false)
measure_delivery("broadcast", 10000, 1, false)
measure_delivery("broadcast", 1000, 32, false)
io.write("scenario,subscriptions,roles,scopes,median_batch_ms,max_batch_ms\n")
for _, count in ipairs({ 1000, 10000 }) do
  for _, operation in ipairs({ "unregister_role", "unregister_signal", "dispose" }) do
    measure_cleanup(count, operation, 1, 1)
    measure_cleanup(count, operation, count, 1)
    measure_cleanup(count, operation, 1, count)
    measure_cleanup(count, operation, count, count)
  end
end
