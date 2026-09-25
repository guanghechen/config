---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.treeview" ---@type string

local async = require("ux.treeview.async")
local State = require("ux.treeview.state")
local Provider = require("ux.treeview.provider")
local Upload = require("ux.treeview.upload")

---@class ux.treeview.Data
---@field _pending_reads                table<string, table>
---@field _native                       yoz.ux.treeview.Data
---@field _read_children                ?fun(request: ux.treeview.IRequest): ux.treeview.IPage|stl.c.Future
---@field _on_effect                    ?fun(effect: ux.treeview.IEffect): nil
---@field _views                        table<ux.treeview.View, boolean>
---@field _queries                      table<string, ux.treeview.Query>
---@field _works                        table<string, table>
local Data = {}
Data.__index = Data

---@param scope                         ?ux.treeview.IDataScope
---@param base_revision                 ?string
---@return ux.treeview.Upload
function Data:begin_import(scope, base_revision)
  return Upload.new(self._native:begin_import(scope, base_revision or self:source():revision()))
end

---@param records                       ux.treeview.Records
---@param scope                         ?ux.treeview.IDataScope
---@param base_revision                 ?string
---@return stl.c.Future
function Data:import(records, scope, base_revision)
  return async.run(self._native:import({
    records = records,
    scope = scope,
    base_revision = base_revision or self._native:source():revision(),
  }))
end

---@param operations                    ux.treeview.IOperation[]
---@param base_revision                 ?string
---@return stl.c.Future
function Data:batch(operations, base_revision)
  return async.run(self._native:batch({
    operations = operations,
    base_revision = base_revision or self._native:source():revision(),
  }))
end

---@param authorization                 string
---@param operations                    ux.treeview.IOperation[]
---@param base_revision                 ?string
---@return stl.c.Future
function Data:task_batch(authorization, operations, base_revision)
  return async.run(self._native:task_batch({
    operations = operations,
    base_revision = base_revision or self._native:source():revision(),
  }, authorization))
end

---@return yoz.ux.treeview.Source
function Data:source()
  return self._native:source()
end

---@param root                          ux.treeview.IRoot
---@param display                       ?ux.treeview.IDisplay
---@return stl.c.Future
function Data:create_state(root, display)
  return async.run(self._native:create_state(root, display)):map(function(value)
    return type(value) == "userdata" and State.new(self, value) or value
  end)
end

---@param scope                         ux.treeview.IDataScope
---@return stl.c.Future
function Data:create_provider(scope)
  return async.run(self._native:create_provider(scope)):map(function(value)
    return type(value) == "userdata" and Provider.new(self, value) or value
  end)
end

---@param nodes                         string[]
---@param retry                         ?boolean
---@return stl.c.Future
function Data:request_children(nodes, retry)
  return async.run(self._native:request_children(nodes, retry))
end

---@param event                         table
---@param work                          table
---@param ok                            boolean
---@param result                        any
---@return nil
function Data:_finish_page(event, work, ok, result)
  if work.finished then
    return
  end
  work.finished = true
  local native_ticket
  if work.cancelled then
    native_ticket = event.kind == "Query" and self._native:query_cancelled(event.token)
      or self._native:children_cancelled(event.token)
  elseif not ok or type(result) ~= "table" or result.error then
    local error
    if type(result) == "table" and result.error then
      error = result.error
    elseif not ok then
      error = { code = "ProviderError", message = tostring(result) }
    else
      error = { code = "InvalidUpdate", message = "Provider must return {records, done}" }
    end
    native_ticket = event.kind == "Query" and self._native:query_failed(event.token, event.sequence, error)
      or self._native:children_failed(event.token, event.sequence, error)
  else
    native_ticket = event.kind == "Query"
        and self._native:query_page(event.token, event.sequence, result.records, result.done)
      or self._native:children_page(event.token, event.sequence, result.records, result.done)
  end
  async.run(native_ticket):finally(function(ok, result)
    if ok and result.kind == "Applied" and self._on_effect then
      for _, event in ipairs(result.effects) do
        if event.kind == "NodeInvalidated" then
          local success, error = pcall(self._on_effect, event)
          if not success then
            async.report(error)
          end
        end
      end
    end
    if self._works[event.work] == work then
      self._works[event.work] = nil
    end
  end)
end

---@param event                         table
---@return nil
function Data:_start_page(event)
  local work = { cancelled = false, finished = false, token = event.token, sequence = event.sequence }
  self._works[event.work] = work
  local query = event.kind == "Query" and self._queries[event.session] or nil
  local handler = query and query._handler or self._read_children
  if event.kind == "Query" and not query then
    handler = nil
  end
  if not handler then
    self:_finish_page(event, work, false, "No provider is attached for this read")
    return
  end
  local request = {
    work = event.work,
    token = event.token,
    sequence = event.sequence,
    node = event.node,
    pattern = event.pattern,
    options = event.options,
    source = self:source(),
    is_cancelled = function()
      return work.cancelled
    end,
  }
  local ok, result = pcall(handler, request)
  if ok and type(result) == "table" and type(result.finally) == "function" then
    result:finally(function(success, value)
      self:_finish_page(event, work, success, value)
    end)
  else
    self:_finish_page(event, work, ok, result)
  end
end

---@return boolean
function Data:_poll()
  for _, event in ipairs(self._native:events()) do
    if event.kind == "NeedChildren" or event.kind == "Query" then
      self._pending_reads[event.work] = event
    elseif event.kind == "CancelChildren" or event.kind == "CancelQuery" then
      self._pending_reads[event.work] = nil
      local work = self._works[event.work]
      if work then
        work.cancelled = true
      else
        if event.kind == "CancelQuery" then
          local token = event.token
          ---@cast token yoz.ux.treeview.QueryToken
          async.run(self._native:query_cancelled(token))
        else
          local token = event.token
          ---@cast token yoz.ux.treeview.ReadToken
          async.run(self._native:children_cancelled(token))
        end
      end
    elseif self._on_effect then
      local ok, error = pcall(self._on_effect, event)
      if not ok then
        async.report(error)
      end
    end
  end
  for view in pairs(self._views) do
    view:_poll()
  end
  local preparing = false
  for view in pairs(self._views) do
    local revisions = view._state:status().revisions
    if
      not view._closed
      and not view._gesture
      and not view._render_error
      and not view._projection_error
      and (
        view._busy
        or view._latest
        or (
          view._header
          and (view._header.data_revision ~= revisions.data or view._header.state_revision ~= revisions.state)
        )
      )
    then
      preparing = true
      break
    end
  end
  for work, event in pairs(self._pending_reads) do
    if event.first or not preparing then
      self._pending_reads[work] = nil
      self:_start_page(event)
    end
  end
  return preparing
end

local M = {}

---@param options                       ?ux.treeview.IDataOptions
---@return ux.treeview.Data
function M.new_data(options)
  options = options or {}
  local native = (rawget(_G, "yoz") or require("yoz")).ux.treeview
  return M.from_native(native.new_data(options.limits), options)
end

---@param native                        yoz.ux.treeview.Data
---@param options                       ?ux.treeview.IDataOptions
---@return ux.treeview.Data
function M.from_native(native, options)
  options = options or {}
  local data = setmetatable({
    _native = native,
    _read_children = options.read_children,
    _on_effect = options.on_effect,
    _views = setmetatable({}, { __mode = "k" }),
    _queries = setmetatable({}, { __mode = "v" }),
    _works = {},
    _pending_reads = {},
  }, Data)
  async.watch(data)
  return data
end

---@param state                         ux.treeview.State
---@param options                       ?ux.treeview.IViewOptions
---@return ux.treeview.View
function M.attach(state, options)
  return require("ux.treeview.view").new(state, options)
end

return M
