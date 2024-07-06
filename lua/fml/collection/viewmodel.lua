local BatchDisposable = require("fml.collection.batch_disposable")
local Disposable = require("fml.collection.disposable")
local Subscriber = require("fml.collection.subscriber")
local is_disposable = require("fml.fn.is_disposable")
local is_observable = require("fml.fn.is_observable")
local dispose_all = require("fml.fn.dispose_all")
local fs = require("fml.std.fs")
local reporter = require("fml.std.reporter")

---@class fml.collection.Viewmodel : fml.types.collection.IViewmodel
---@field private _name                 string
---@field private _filepath             string|nil
---@field private _initial_values       table<string, any>
---@field private _unwatch              (fun():nil)|nil
---@field private _verbose              boolean
---@field private _persistables         table<string, fml.types.collection.IObservable>
---@field private _all_observables      table<string, fml.types.collection.IObservable>
local Viewmodel = {}
Viewmodel.__index = Viewmodel
setmetatable(Viewmodel, { __index = BatchDisposable })

---@class fml.collection.Viewmodel.IProps
---@field public name                   string
---@field public filepath               ?string
---@field public verbose                ?boolean

---@param props                         fml.collection.Viewmodel.IProps
---@return fml.collection.Viewmodel
function Viewmodel.new(props)
  local self = setmetatable(BatchDisposable.new(), Viewmodel)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast self fml.collection.Viewmodel

  self._name = props.name ---@type string
  self._filepath = props.filepath ---@type string
  self._initial_values = {} ---@type table<string, any>
  self._unwatch = nil ---@type (fun():nil)|nil
  self._persistables = {} ---@type table<string, fml.types.collection.IObservable>
  self._verbose = not not props.verbose ---@type boolean
  self._all_observables = {} ---@type table<string, fml.types.collection.IObservable>

  return self
end

---@return nil
function Viewmodel:dispose()
  if self:is_disposed() then
    return
  end

  BatchDisposable.dispose(self)

  ---@type fml.types.collection.IDisposable[]
  local disposables = {}
  for _, disposable in pairs(self) do
    if is_disposable(disposable) then
      ---@cast disposable fml.types.collection.IDisposable
      table.insert(disposables, disposable)
    end
  end

  if self._unwatch then
    self._unwatch()
    self._unwatch = nil
  end

  dispose_all(disposables)
end

function Viewmodel:get_name()
  return self._name
end

function Viewmodel:get_filepath()
  return self._filepath
end

---@return table<string, any>
function Viewmodel:get_snapshot()
  local data = {}
  for key, observable in pairs(self._persistables) do
    if is_observable(observable) then
      ---@cast observable fml.types.collection.IObservable
      data[key] = observable:get_snapshot()
    end
  end
  return data
end

---@return table<string, any>
function Viewmodel:get_snapshot_all()
  local data = {}
  for key, observable in pairs(self._all_observables) do
    if is_observable(observable) then
      ---@cast observable fml.types.collection.IObservable
      data[key] = observable:get_snapshot()
    end
  end
  return data
end

---@param name string
---@param observable fml.types.collection.IObservable
---@param persistable boolean
---@param auto_save boolean
function Viewmodel:register(name, observable, persistable, auto_save)
  if persistable then
    self._persistables[name] = observable
  end

  self[name] = observable
  self._all_observables[name] = observable

  if auto_save then
    self._initial_values[name] = observable:get_snapshot()
    local subscriber = Subscriber.new({
      on_next = function(next_value)
        if not observable.equals(self._initial_values[name], next_value) then
          self._initial_values[name] = next_value
          self:save()
        end
      end,
    })
    local unsubscribable = observable:subscribe(subscriber)
    self:add_disposable(Disposable.new({
      on_dispose = function()
        unsubscribable:unsubscribe()
      end,
    }))
  end

  return self
end

function Viewmodel:save()
  local filepath = self._filepath ---@type string|nil
  if filepath == nil then
    reporter.error({
      from = "fml.collection.viewmodel",
      subject = "save",
      message = "The filepath not specified",
      details = { name = self._name },
    })
    return
  end

  local data = self:get_snapshot() ---@type table
  fs.write_json(filepath, data)
end

---@return boolean  Indicate whether if the content loaded is different with current data.
function Viewmodel:load()
  local filepath = self._filepath ---@type string|nil
  if filepath == nil then
    reporter.error({
      from = "fml.collection.viewmodel",
      subject = "load",
      message = "The filepath not specified",
      details = { name = self._name },
    })
    return false
  end

  local data = fs.read_json({ filepath = filepath, silent_on_bad_path = true })
  if type(data) ~= "table" then
    if data ~= nil then
      reporter.warn({
        from = "fml.collection.viewmodel",
        subject = "load",
        message = "Bad json, not a table",
        details = { name = self._name, data = data },
      })
    end
    return false
  end

  local has_changed = false ---@type boolean
  for key, value in pairs(data) do
    local observable = self[key]
    if value ~= nil and is_observable(observable) then
      self._initial_values[key] = value
      has_changed = observable:next(value) or has_changed
    end
  end
  return has_changed
end

---@param params                        ?fml.types.collection.viewmodel.IAutoReloadParams
---@return nil
function Viewmodel:auto_reload(params)
  params = params or {}
  ---@cast params fml.types.collection.viewmodel.IAutoReloadParams

  local on_changed = params.on_changed or fml.fn.noop ---@type fun(): nil


  if self._unwatch ~= nil then
    return
  end

  local filepath = self._filepath ---@type string|nil
  if filepath == nil then
    reporter.error({
      from = "fml.collection.viewmodel",
      subject = "auto_reload",
      message = "The filepath not specified",
      details = { name = self._name, params, params },
    })
    return false
  end

  local unwatch = fs.watch_file({
    filepath = filepath,
    on_event = function(filepath, event)
      if type(event) == "table" and event.change == true then
        local has_changed = self:load()
        if has_changed then
          vim.schedule(on_changed)
          if self._verbose then
            reporter.info({
              from = "fml.collection.viewmodel",
              subject = "auto_reload",
              message = "auto reloaded.",
              details = { name = self._name, filepath = filepath },
              --details = { name = self._name, filepath = filepath, event = event },
            })
          end
        end
      end
    end,
    on_error = function(filepath, err)
      reporter.error({
        from = "fml.collection.viewmodel",
        subject = "auto_reload",
        message = "Failed!",
        details = { err = err, name = self._name, filepath = filepath },
      })
    end,
  })
  self._unwatch = unwatch
end

return Viewmodel
