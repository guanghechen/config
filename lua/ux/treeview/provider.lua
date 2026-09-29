---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.treeview.provider" ---@type string

local async = require("ux.treeview.async")

---@class ux.treeview.Query
---@field _native                       yoz.ux.treeview.Query
---@field _provider                     ux.treeview.Provider
---@field _handler                      fun(request: ux.treeview.IRequest): ux.treeview.IPage|stl.c.Future
local Query = {}
Query.__index = Query

---@param input                         ux.treeview.IQueryInput
---@return stl.c.Future
function Query:start(input)
  return async.run(self._native:start(input))
end

---@return stl.c.Future
function Query:cancel()
  return async.run(self._native:cancel())
end

---@return table
function Query:info()
  return self._native:info()
end

---@class ux.treeview.Provider
---@field _native                       yoz.ux.treeview.Provider
---@field _data                         ux.treeview.Data
local M = {}
M.__index = M

---@param base_revision                 ?string
---@return ux.treeview.Upload
function M:begin_import(base_revision)
  return require("ux.treeview.upload").new(self._native:begin_import(base_revision or self._data:source():revision()))
end

---@param data                          ux.treeview.Data
---@param native                        yoz.ux.treeview.Provider
---@return ux.treeview.Provider
function M.new(data, native)
  return setmetatable({ _data = data, _native = native }, M)
end

---@param records                       ux.treeview.Records
---@param base_revision                 ?string
---@return stl.c.Future
function M:import(records, base_revision)
  return async.run(self._native:import(base_revision or self._data:source():revision(), records))
end

---@param operations                    ux.treeview.IOperation[]
---@param base_revision                 ?string
---@return stl.c.Future
function M:batch(operations, base_revision)
  return async.run(self._native:batch({
    operations = operations,
    base_revision = base_revision or self._data:source():revision(),
  }))
end

---@param handler                       fun(request: ux.treeview.IRequest): ux.treeview.IPage|stl.c.Future
---@return stl.c.Future
function M:create_query(handler)
  return async.run(self._native:create_query()):map(function(result)
    if type(result) ~= "userdata" then
      return result
    end
    local query = setmetatable({ _native = result, _provider = self, _handler = handler }, Query)
    self._data._queries[result:id()] = query
    return query
  end)
end

return M
