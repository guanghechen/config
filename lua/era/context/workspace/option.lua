---@class era.context.option.data
---@field public expandtab              boolean
---@field public relativenumber         boolean
---@field public notepad_source         string

---@class era.context.option.state
---@field public expandtab              ark.c.Observable
---@field public relativenumber         ark.c.Observable
---@field public notepad_source         ark.c.Observable

---@class era.context.option : era.context.option.state
---@field public defaults               fun(): era.context.option.data
---@field public dump                   fun(): era.context.option.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): era.context.option.data
local M = {}

---@return era.context.option.data
function M.defaults()
  ---@type era.context.option.data
  return {
    expandtab = true,
    relativenumber = true,
    notepad_source = "workspace",
  }
end

---@param data                          any
---@return era.context.option.data
function M.normalize(data)
  local resolved = M.defaults() ---@type era.context.option.data
  if type(data) == "table" then
    if type(data.expandtab) == "boolean" then
      resolved.expandtab = data.expandtab
    end
    if type(data.relativenumber) == "boolean" then
      resolved.relativenumber = data.relativenumber
    end
    if type(data.notepad_source) == "string" then
      resolved.notepad_source = data.notepad_source
    end
  end

  ---@type era.context.option.data
  return resolved
end

---@return era.context.option.data
function M.dump()
  ---@type era.context.option.data
  return {
    expandtab = M.expandtab:snapshot(),
    relativenumber = M.relativenumber:snapshot(),
    notepad_source = M.notepad_source:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type era.context.option.data

  M.expandtab:next(data.expandtab)
  M.relativenumber:next(data.relativenumber)
  M.notepad_source:next(data.notepad_source)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type era.context.option.data
M.expandtab = ark.c.Observable.from_value(_defaults.expandtab)
M.relativenumber = ark.c.Observable.from_value(_defaults.relativenumber)
M.notepad_source = ark.c.Observable.from_value(_defaults.notepad_source)

return M
