---@class guanghechen.disposable.History: guanghechen.types.IHistory
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

---@param step? number
---@return guanghechen.types.T|nil
function History:back(step)
  step = 1
  if step < 1 then
    step = 1
  end

  local idx = self._present_idx - step ---@type number
  local stack = self._stack ---@type guanghechen.types.T[]
  if idx < 0 then
    idx = 0
  end

  self._present_idx = idx
  if idx > 0 and idx <= #stack then
    return stack[idx]
  end
  return nil
end

---@param step? number
---@return guanghechen.types.T|nil
function History:forward(step)
  step = 1
  if step < 1 then
    step = 1
  end

  local idx = self._present_idx + step ---@type number
  local stack = self._stack ---@type guanghechen.types.T[]
  if idx > #stack then
    idx = #stack
  end

  self._present_idx = idx
  if idx > 0 and idx <= #stack then
    return stack[idx]
  end
  return nil
end

---@param element guanghechen.types.T
---@return nil
function History:push(element)
  local idx = self._present_idx + 1 ---@type number
  local stack = self._stack ---@type guanghechen.types.T[]
  local N = #stack ---@type number
  if idx <= N then
    local old = stack[idx] ---@type guanghechen.types.T
    local delta = self._comparator(old, element)
    if delta ~= 0 then
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

return History
