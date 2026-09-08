---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.c.signal_hub" ---@type string

--- Identity metadata is readonly. Routing uses the registered table identity.
---@class stl.c.signal_hub.IRole
---@field public id                     integer
---@field public name                   string

---@class stl.c.signal_hub.ITrack
---@field public from                   stl.c.signal_hub.IRole
---@field public to                     ?stl.c.signal_hub.IRole
---@field public original               stl.c.signal_hub.IRole

--- Messages, payloads and identities are readonly across subscriber boundaries.
---@class stl.c.signal_hub.IMessage
---@field public signal                 string
---@field public scope                  string
---@field public payload                any
---@field public track                  stl.c.signal_hub.ITrack

---@class stl.c.signal_hub.IEmission
---@field public signal                 string
---@field public scope                  string
---@field public payload                ?any
---@field public track                  ?{ to?: stl.c.signal_hub.IRole }

---@class stl.c.signal_hub.IFilter
---@field public signal                 ?string Omitted matches every registered signal.
---@field public scope                  ?string Omitted matches every scope.

---@class stl.c.signal_hub.IRoute
---@field public scope                  ?string Omitted inherits the message scope.
---@field public to                     ?stl.c.signal_hub.IRole Omitted broadcasts.

---@class stl.c.signal_hub.IDeliveryError
---@field public role                   stl.c.signal_hub.IRole
---@field public error                  any

---@class stl.c.signal_hub.ISubscription
---@field public unsubscribe            fun(self: stl.c.signal_hub.ISubscription): nil
---@field _hub                          ?stl.c.SignalHub
---@field _role                         ?stl.c.signal_hub.IRole
---@field _signal                       any
---@field _scope                        any
---@field _callback                     ?fun(message: stl.c.signal_hub.IMessage): nil
---@field _global_node                  ?stl.c.signal_hub.INode
---@field _role_node                    ?stl.c.signal_hub.INode

---@class stl.c.signal_hub.INode
---@field subscription                  stl.c.signal_hub.ISubscription
---@field previous                      ?stl.c.signal_hub.INode
---@field next                          ?stl.c.signal_hub.INode

---@class stl.c.signal_hub.IBucket
---@field first                         ?stl.c.signal_hub.INode
---@field last                          ?stl.c.signal_hub.INode

---@class stl.c.signal_hub.IScopes
---@field buckets                       table<any, stl.c.signal_hub.IBucket>
---@field count                         integer

---@alias stl.c.signal_hub.IIndex table<any, stl.c.signal_hub.IScopes>

---@class stl.c.SignalHub
---@field _disposed                     boolean
---@field _next_role                    integer
---@field _signals                      table<string, table>
---@field _roles                        table<stl.c.signal_hub.IRole, stl.c.signal_hub.IIndex>
---@field _known_roles                  table<stl.c.signal_hub.IRole, boolean>
---@field _subscriptions                stl.c.signal_hub.IIndex
local M = {}
M.__index = M

local ANY = {}

---@param hub                           stl.c.SignalHub
---@return nil
local function check_alive(hub)
  assert(not hub._disposed, "Signal hub has been disposed")
end

---@param hub                           stl.c.SignalHub
---@param role                          stl.c.signal_hub.IRole
---@param active                        boolean
---@return nil
local function check_role(hub, role, active)
  assert(hub._known_roles[role], "Role is not registered with this hub")
  assert(not active or hub._roles[role], "Role has been unregistered")
end

---@param index                         stl.c.signal_hub.IIndex
---@param subscription                  stl.c.signal_hub.ISubscription
---@return stl.c.signal_hub.INode
local function insert(index, subscription)
  local scopes = index[subscription._signal]
  if scopes == nil then
    scopes = { buckets = {}, count = 0 }
    index[subscription._signal] = scopes
  end
  local bucket = scopes.buckets[subscription._scope]
  if bucket == nil then
    bucket = {}
    scopes.buckets[subscription._scope] = bucket
    scopes.count = scopes.count + 1
  end
  local node = { subscription = subscription, previous = bucket.last }
  if bucket.last then
    bucket.last.next = node
  else
    bucket.first = node
  end
  bucket.last = node
  return node
end

---@param index                         stl.c.signal_hub.IIndex
---@param subscription                  stl.c.signal_hub.ISubscription
---@param node                          stl.c.signal_hub.INode
---@return nil
local function remove(index, subscription, node)
  local scopes = index[subscription._signal]
  local bucket = scopes.buckets[subscription._scope]
  if node.previous then
    node.previous.next = node.next
  else
    bucket.first = node.next
  end
  if node.next then
    node.next.previous = node.previous
  else
    bucket.last = node.previous
  end
  node.previous, node.next = nil, nil
  if bucket.first == nil then
    scopes.buckets[subscription._scope] = nil
    -- Avoid rescanning cleared hash slots when removing many different scopes.
    scopes.count = scopes.count - 1
    if scopes.count == 0 then
      index[subscription._signal] = nil
    end
  end
end

---@param subscriptions                 stl.c.signal_hub.ISubscription[]
---@param bucket                        ?stl.c.signal_hub.IBucket
---@return nil
local function append(subscriptions, bucket)
  local node = bucket and bucket.first
  while node do
    subscriptions[#subscriptions + 1] = node.subscription
    node = node.next
  end
end

---@param index                         stl.c.signal_hub.IIndex
---@return stl.c.signal_hub.ISubscription[]
local function collect(index)
  local subscriptions = {}
  for _, scopes in pairs(index) do
    for _, bucket in pairs(scopes.buckets) do
      append(subscriptions, bucket)
    end
  end
  return subscriptions
end

---@param subscription                  stl.c.signal_hub.ISubscription
---@return nil
local function unsubscribe(subscription)
  local hub = subscription._hub
  if hub == nil then
    return
  end
  local role = assert(subscription._role)
  remove(hub._subscriptions, subscription, assert(subscription._global_node))
  remove(hub._roles[role], subscription, assert(subscription._role_node))
  subscription._hub = nil
  subscription._role = nil
  subscription._signal = nil
  subscription._scope = nil
  subscription._callback = nil
  subscription._global_node = nil
  subscription._role_node = nil
end

---@param hub                           stl.c.SignalHub
---@param message                       stl.c.signal_hub.IMessage
---@return integer delivered
---@return stl.c.signal_hub.IDeliveryError[]|nil errors
local function dispatch(hub, message)
  local index = hub._subscriptions
  if message.track.to ~= nil then
    index = hub._roles[message.track.to]
    if index == nil then
      return 0, nil
    end
  end
  local exact = index[message.signal]
  local wildcard = index[ANY]
  if exact == nil and wildcard == nil then
    return 0, nil
  end

  -- Snapshot recipients before invoking callbacks; removals still take effect immediately.
  local subscriptions = {}
  append(subscriptions, exact and exact.buckets[message.scope])
  append(subscriptions, exact and exact.buckets[ANY])
  append(subscriptions, wildcard and wildcard.buckets[message.scope])
  append(subscriptions, wildcard and wildcard.buckets[ANY])

  local registration = hub._signals[message.signal]
  local delivered = 0
  local errors = nil ---@type stl.c.signal_hub.IDeliveryError[]|nil
  for _, subscription in ipairs(subscriptions) do
    if hub._disposed or hub._signals[message.signal] ~= registration then
      break
    end
    local callback, role = subscription._callback, subscription._role
    if subscription._hub == hub and callback and role then
      local ok, err = pcall(callback, message)
      if ok then
        delivered = delivered + 1
      else
        errors = errors or {}
        errors[#errors + 1] = { role = role, error = err }
      end
    end
  end
  return delivered, errors
end

---@return stl.c.SignalHub
function M.new()
  return setmetatable({
    _disposed = false,
    _next_role = 0,
    _signals = {},
    _roles = {},
    _known_roles = setmetatable({}, { __mode = "k" }),
    _subscriptions = {},
  }, M)
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  for _, subscription in ipairs(collect(self._subscriptions)) do
    unsubscribe(subscription)
  end
  self._signals = {}
  self._roles = {}
  self._known_roles = setmetatable({}, { __mode = "k" })
end

---@param name                          string
---@return string
function M:register_signal(name)
  check_alive(self)
  assert(type(name) == "string" and name ~= "", "Expected a non-empty signal name")
  assert(self._signals[name] == nil, "Signal is already registered")
  self._signals[name] = {}
  return name
end

---@param signal                        string
---@return nil
function M:unregister_signal(signal)
  check_alive(self)
  assert(self._signals[signal], "Signal is not registered")
  self._signals[signal] = nil
  local subscriptions = {}
  local scopes = self._subscriptions[signal]
  if scopes then
    for _, bucket in pairs(scopes.buckets) do
      append(subscriptions, bucket)
    end
  end
  for _, subscription in ipairs(subscriptions) do
    unsubscribe(subscription)
  end
end

---@param name                          string
---@return stl.c.signal_hub.IRole
function M:register_role(name)
  check_alive(self)
  assert(type(name) == "string" and name ~= "", "Expected a non-empty role name")
  self._next_role = self._next_role + 1
  local role = { id = self._next_role, name = name }
  self._known_roles[role] = true
  self._roles[role] = {}
  return role
end

---@param role                          stl.c.signal_hub.IRole
---@return nil
function M:unregister_role(role)
  check_alive(self)
  check_role(self, role, false)
  local index = self._roles[role]
  if index == nil then
    return
  end
  for _, subscription in ipairs(collect(index)) do
    unsubscribe(subscription)
  end
  self._roles[role] = nil
end

---@param role                          stl.c.signal_hub.IRole
---@param filter                        stl.c.signal_hub.IFilter
---@param callback                      fun(message: stl.c.signal_hub.IMessage): nil
---@return stl.c.signal_hub.ISubscription
function M:subscribe(role, filter, callback)
  check_alive(self)
  check_role(self, role, true)
  assert(type(filter) == "table", "Expected a subscription filter")
  local signal, scope = filter.signal, filter.scope
  assert(signal == nil or self._signals[signal], "Signal is not registered")
  assert(scope == nil or (type(scope) == "string" and scope ~= ""), "Invalid scope")
  assert(type(callback) == "function", "Expected a subscriber callback")

  ---@type stl.c.signal_hub.ISubscription
  local subscription = {
    unsubscribe = unsubscribe,
    _hub = self,
    _role = role,
    _signal = signal or ANY,
    _scope = scope or ANY,
    _callback = callback,
  }
  subscription._global_node = insert(self._subscriptions, subscription)
  subscription._role_node = insert(self._roles[role], subscription)
  return subscription
end

--- Delivery is synchronous. Each successful callback counts once; errors are returned to the caller.
---@param role                          stl.c.signal_hub.IRole
---@param emission                      stl.c.signal_hub.IEmission
---@return integer delivered
---@return stl.c.signal_hub.IDeliveryError[]|nil errors
function M:emit(role, emission)
  check_alive(self)
  check_role(self, role, true)
  assert(type(emission) == "table", "Expected a signal emission")
  assert(self._signals[emission.signal], "Signal is not registered")
  assert(type(emission.scope) == "string" and emission.scope ~= "", "Invalid scope")
  local track = emission.track
  assert(track == nil or type(track) == "table", "Invalid track")
  local target = track and track.to
  if target ~= nil then
    check_role(self, target, false)
  end
  return dispatch(self, {
    signal = emission.signal,
    scope = emission.scope,
    payload = emission.payload,
    track = { from = role, to = target, original = role },
  })
end

--- The route replaces the destination: an omitted `to` broadcasts, and an omitted scope is inherited.
---@param role                          stl.c.signal_hub.IRole
---@param message                       stl.c.signal_hub.IMessage
---@param route                         stl.c.signal_hub.IRoute
---@return integer delivered
---@return stl.c.signal_hub.IDeliveryError[]|nil errors
function M:forward(role, message, route)
  check_alive(self)
  check_role(self, role, true)
  assert(type(message) == "table" and type(message.track) == "table", "Expected a signal message")
  assert(self._signals[message.signal], "Signal is not registered")
  check_role(self, message.track.from, false)
  check_role(self, message.track.original, false)
  assert(type(route) == "table", "Expected a forwarding route")
  local scope = route.scope
  if scope == nil then
    scope = message.scope
  end
  assert(type(scope) == "string" and scope ~= "", "Invalid scope")
  if route.to ~= nil then
    check_role(self, route.to, false)
  end
  return dispatch(self, {
    signal = message.signal,
    scope = scope,
    payload = message.payload,
    track = { from = role, to = route.to, original = message.track.original },
  })
end

return M
