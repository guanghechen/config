---@class guanghechen.history.History: guanghechen.types.IHistory
---@field private _comparator fun(x:guanghechen.types.T, y:guanghechen.types.T): number
---@field private _name string
---@field private _present_idx number
---@field private _stack guanghechen.types.T[]
local History = {}
History.__index = History

---@param opts { name: string, comparator: fun(x:guanghechen.types.T, y:guanghechen.types.T): number }
function History.new(opts)
  local self = setmetatable({}, History)

  self._name = opts.name ---@type string
  self._comparator = opts.comparator
  self._present_idx = 0 ---@type number
  self._stack = {} ---@type guanghechen.types.T[]

  return self
end

---@return string
function History:name()
  return self._name
end

---@return guanghechen.types.T|nil
function History:present()
  local idx = self._present_idx ---@type number
  local stack = self._stack ---@type guanghechen.types.T[]
  if idx > 0 and idx <= #stack then
    return stack[idx]
  end
  return nil
end

---@return number
function History:present_index()
  return self._present_idx
end

---@param step? number
---@return guanghechen.types.T|nil
function History:back(step)
  if step == nil or step < 1 then
    step = 1
  end

  local idx = self._present_idx - step ---@type number
  if idx < 1 then
    idx = 1
  end

  self._present_idx = idx
  return self._stack[idx]
end

---@param step? number
---@return guanghechen.types.T|nil
function History:forward(step)
  if step == nil or step < 1 then
    step = 1
  end

  local idx = self._present_idx + step ---@type number
  local stack = self._stack ---@type guanghechen.types.T[]
  if idx > #stack then
    idx = #stack
  end

  self._present_idx = idx
  return stack[idx]
end

---@param index number
---@return guanghechen.types.T|nil
function History:go(index)
  local idx = index ---@type number
  local stack = self._stack ---@type guanghechen.types.T[]
  if idx > 0 and idx <= #stack then
    self._present_idx = idx
    return stack[idx]
  end
  return nil
end

---@param element guanghechen.types.T
---@return nil
function History:push(element)
  local idx = self._present_idx ---@type number
  local stack = self._stack ---@type guanghechen.types.T[]
  local top = stack[idx]
  if top ~= nil and self._comparator(top, element) == 0 then
    return
  end

  idx = idx + 1
  if idx <= #stack then
    local delta = self._comparator(stack[idx], element)
    if delta ~= 0 then
      local N = #stack ---@type number
      ---@diagnostic disable-next-line: unused-local
      for i = idx, N do
        table.remove(stack, idx)
      end
      stack[idx] = element
    end
    self._present_idx = idx
  else
    table.insert(stack, element)
    self._present_idx = #stack
  end
end

function History:iterator()
  local stack = self._stack
  local index = 0
  return function()
    index = index + 1
    if index <= #stack then
      return stack[index]
    end
  end
end

function History:iterator_reverse()
  local stack = self._stack
  local index = #stack
  return function()
    if index > #stack then
      index = #stack
    end

    local idx = index
    index = index - 1

    if idx > 0 then
      return stack[idx]
    end
  end
end

function History:print()
  vim.notify(vim.inspect({ stack = self._stack, present_index = self._present_idx }))
end

return History
