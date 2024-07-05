local reporter = require("fml.std.reporter")
local std_array = require("fml.std.array")

---@class fml.collection.History : fml.types.collection.IHistory

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

---@param history                       fml.types.collection.IHistory
---@param new_name                      ?string
---@return fml.collection.History
function M.from(history, new_name)
  local self = setmetatable({}, M)

  self.name = new_name or history.name
  self.equals = history.equals
  self.validate = history.validate

  self._stack = std_array.slice(history._stack)
  self._present_idx = history._present_idx

  return self
end

---@return nil
function M:clear()
  self._present_idx = 0
  self._stack = {}
end

---@return boolean
function M:empty()
  return self:solid_present() == nil
end

---@param params                        ?fml.types.collection.IHistoryForkParams
---@return fml.collection.History
function M:fork(params)
  local new_name = params and params.name
  return M.from(self, new_name)
end

---@param idx                           integer
---@return fml.types.T|nil
function M:go(idx)
  idx = math.max(1, math.min(#self._stack, idx))
  self._present_idx = idx
  return self._stack[idx]
end

function M:iterator()
  local i = 0 ---@type integer
  return function()
    while true do
      i = i + 1
      if i > #self._stack then
        return nil
      end

      local element = self._stack[i]
      if self.validate(element) then
        return element, i
      end
    end
  end
end

function M:iterator_reverse()
  local i = #self._stack + 1 ---@type integer
  return function()
    while true do
      i = i - 1
      if i < 1 then
        return nil
      end

      if i <= #self._stack then
        local element = self._stack[i]
        if self.validate(element) then
          return element, i
        end
      end
    end
  end
end

---@return integer
function M:present_index()
  return self._present_idx
end

---@return nil
function M:print()
  local history = {} ---@type fml.types.T[]
  for _, element in ipairs(self._stack) do
    if self.validate(element) then
      table.insert(history, element)
    end
  end
  reporter.info({
    from = "fml.collection.history",
    subject = "print",
    message = "History",
    details = { history = history, present = self:solid_present() },
  })
end

---@param element                       fml.types.T
---@return nil
function M:push(element)
  if not self.validate(element) then
    return
  end

  self:solid_present()
  local present_idx = self._present_idx ---@type integer
  if present_idx < #self._stack then
    local next_element = self:solid_forward(1)
    if self.equals(next_element, element) then
      return
    end
    self._resent_idx = present_idx
  end

  while self._present_idx < #self._stack do
    table.remove(self._stack)
  end
  table.insert(self._stack, element)
  self._present_idx = self._present_idx + 1
end

---@param step                          ?number
---@return fml.types.T|nil
function M:solid_back(step)
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
    if present == nil or self.validate(present) then
      break
    end
    idx = idx - 1
  end

  ---! Rearrange the stack
  if idx < 1 then
    std_array.filter_inline(self._stack, self.validate)
    idx = #self._stack > 0 and 1 or 0
  end

  self._present_idx = idx
  return self._stack[idx]
end

---@param step                          ?number
---@return fml.types.T|nil
function M:solid_forward(step)
  step = math.max(1, step or 1)
  local idx = self._present_idx ---@type integer

  for _ = 1, step, 1 do
    while idx <= #self._stack do
      local present = self._stack[idx] ---@type fml.types.T|nil
      if present == nil or self.validate(present) then
        break
      end
      idx = idx + 1
    end
    idx = idx + 1
  end

  while idx <= #self._stack do
    local present = self._stack[idx] ---@type fml.types.T|nil
    if present == nil or self.validate(present) then
      break
    end
    idx = idx + 1
  end

  ---! Rearrange the stack
  if idx > #self._stack then
    std_array.filter_inline(self._stack, self.validate)
    idx = #self._stack
  end

  self._present_idx = idx
  return self._stack[idx]
end

---@return fml.types.T|nil
function M:solid_present()
  local idx = self._present_idx ---@type integer
  while idx > 0 do
    local present = self._stack[idx] ---@type fml.types.T|nil
    if present == nil or self.validate(present) then
      break
    end
    idx = idx - 1
  end

  idx = idx > 0 and idx or 0
  self.present_idx = idx
  return self._stack[idx]
end

return M
