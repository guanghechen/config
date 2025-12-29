---@class dot.context.option.data
---@field public expandtab              boolean
---@field public relativenumber         boolean

---@class dot.context.option.state
---@field public expandtab              stl.c.Observable
---@field public relativenumber         stl.c.Observable

---@class dot.context.option : dot.context.option.state
---@field public defaults               fun(): dot.context.option.data
---@field public dump                   fun(): dot.context.option.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): dot.context.option.data
local M = {}

---@return dot.context.option.data
function M.defaults()
  ---@type dot.context.option.data
  return {
    expandtab = true,
    relativenumber = true,
  }
end

---@param data                          any
---@return dot.context.option.data
function M.normalize(data)
  local resolved = M.defaults() ---@type dot.context.option.data
  if type(data) == "table" then
    if type(data.expandtab) == "boolean" then
      resolved.expandtab = data.expandtab
    end
    if type(data.relativenumber) == "boolean" then
      resolved.relativenumber = data.relativenumber
    end
  end

  ---@type dot.context.option.data
  return resolved
end

---@return dot.context.option.data
function M.dump()
  ---@type dot.context.option.data
  return {
    expandtab = M.expandtab:snapshot(),
    relativenumber = M.relativenumber:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type dot.context.option.data

  M.expandtab:next(data.expandtab)
  M.relativenumber:next(data.relativenumber)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type dot.context.option.data
M.expandtab = stl.c.Observable.from_value(_defaults.expandtab)
M.relativenumber = stl.c.Observable.from_value(_defaults.relativenumber)

return M
