local reporter = require("fml.std.reporter")
local std_array = require("fml.std.array")

---@class fml.collection.History : fml.types.collection.IHistory
---@field private _present_idx          integer
---@field private _stack                fml.types.T[]

local M = {}
M.__index = M

---@param x                             fml.types.T
---@param y                             fml.types.T
---@return boolean
local function default_equals(x, y)
  return x == y
end

---@param x                             fml.types.T
---@return boolean
---@diagnostic disable-next-line: unused-local
local function default_validate(x)
  return true
end

---@class fml.collection.history.IProps
---@field public name                   string
---@field public max_count              integer
---@field public equals                 ?fun(x: fml.types.T, y: fml.types.T): boolean
---@field public validate               ?fun(v: fml.types.T): boolean

---@param props                         fml.collection.history.IProps
---@return fml.collection.History
function M.new(props)
  local self = setmetatable({}, M)

  self.name = props.name
  self.equals = props.equals or default_equals
  self.validate = props.validate or default_validate

  self._stack = {} ---@type fml.types.T[]
  self._present_idx = 0

  return self
end

---@param step                          ?number
---@return fml.types.T|nil
function M:back(step)
  step = math.max(1, step or 1)
  local idx = self._present_idx ---@type integer

  for _ = 1, step, 1 do
    while idx > 0 do
      local present = self._stack[idx] ---@type fml.types.T|nil
      if present == nil or self.validate(present) then
        break
      end
      idx = idx - 1
    end
    idx = idx - 1
  end

  while idx > 0 do
    local present = self._stack[idx] ---@type fml.types.T|nil
    if self.validate(present) then
      break
    end
    idx = idx - 1
  end

  if idx < 1 or self._present_idx - step > idx then
    self:rearrange()
    self._present_idx = math.min(#self._stack, math.max(1, self._present_idx - step))
    return self._stack[self._present_idx]
  end

  self._present_idx = idx
  return self._stack[idx]
end

---@return nil
function M:clear()
  self._present_idx = 0
  self._stack = {}
end

---@return boolean
function M:empty()
  return self:present() == nil
end

---@param params                        ?fml.types.collection.IHistoryForkParams
---@return fml.collection.History
function M:fork(params)
  self:rearrange()

  local new_name = params and params.name
  local instance = setmetatable({}, M)
  instance.name = new_name
  instance.equals = self.equals
  instance.validate = self.validate
  instance._present_idx = self._present_idx
  instance._stack = std_array.slice(self._stack)

  return instance
end

---@param step                          ?number
---@return fml.types.T|nil
function M:forward(step)
  step = math.max(1, step or 1)
  local idx = self._present_idx ---@type integer

  for _ = 1, step, 1 do
    idx = idx + 1
    while idx <= #self._stack do
      local present = self._stack[idx] ---@type fml.types.T|nil
      if self.validate(present) then
        break
      end
      idx = idx + 1
    end
  end

  if idx > #self._stack then
    idx = #self._stack
    while idx > 0 do
      local present = self._stack[idx] ---@type fml.types.T
      if self.validate(present) then
        break
      end
      idx = idx - 1
    end
  end

  if idx < 1 then
    self:clear()
    return nil
  end

  self._present_idx = idx
  local present = self._stack[idx] ---@type fml.types.T|nil

  if self._present_idx + step > idx then
    self:rearrange()
  end
  return present
end

function M:iterator()
  self:rearrange()

  local i = 0 ---@type integer
  return function()
    i = i + 1
    if i <= #self._stack then
      return self._stack[i], i
    end
  end
end

function M:iterator_reverse()
  self:rearrange()

  local i = #self._stack + 1 ---@type integer
  return function()
    i = i - 1
    if i > 0 then
      return self._stack[i], i
    end
  end
end

---@param idx                           integer
---@return fml.types.T|nil
function M:go(idx)
  self:rearrange()
  idx = math.max(1, math.min(#self._stack, idx))
  self._present_idx = idx
  return self._stack[idx]
end

---@return fml.types.T|nil
function M:present()
  for i = self._present_idx, 1, -1 do
    local present = self._stack[i] ---@type fml.types.T|nil
    if self.validate(present) then
      self._present_idx = i
      return present
    end
  end

  self._present_idx = 0
  return nil
end

function M:present_index()
  self:rearrange()
  return self._present_idx
end

---@return nil
function M:print()
  self:rearrange()

  local present = self._stack[self._present_idx] ---@type fml.types.T|nil
  local history = self._stack

  reporter.info({
    from = "fml.collection.history",
    subject = "print",
    message = "History",
    details = { present = present, history = history },
  })
end

---@param element                       fml.types.T
---@return nil
function M:push(element)
  if not self.validate(element) then
    return
  end

  self:rearrange()

  if self._present_idx < #self._stack then
    local _next_idx = self._present_idx + 1 ---@type integer
    if self.equals(self._stack[_next_idx], element) then
      self._present_idx = _next_idx
      return
    end

    while #self._stack > self._present_idx do
      table.remove(self._stack)
    end
  end

  table.insert(self._stack, element)
  self._present_idx = #self._stack
end

function M:rearrange()
  local old_present_index = self._present_idx ---@type integer
  local new_present_index = 0 ---@type integer
  local idx = 0 ---@type integer

  for i, element in ipairs(self._stack) do
    if self.validate(element) then
      idx = idx + 1
      self._stack[idx] = element

      if new_present_index == 0 and i >= old_present_index then
        new_present_index = i == old_present_index and idx or idx - 1
      end
    end
  end

  while #self._stack > idx do
    table.remove(self._stack)
  end

  self._present_idx = new_present_index == 0 and idx or new_present_index
end

return M
