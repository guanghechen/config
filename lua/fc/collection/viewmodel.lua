local BatchDisposable = require("fc.collection.batch_disposable")
local Disposable = require("fc.collection.disposable")
local Subscriber = require("fc.collection.subscriber")
local fs = require("fc.std.fs")
local is = require("fc.std.is")
local path = require("fc.std.path")
local util = require("fc.std.util")
local reporter = require("fc.std.reporter")

---@class fc.collection.Viewmodel : fc.types.collection.IViewmodel
---@field private _name                 string
---@field private _filepath             string|nil
---@field private _initial_values       table<string, any>
---@field private _unwatch              (fun():nil)|nil
---@field private _verbose              boolean
---@field private _persistables         table<string, fc.types.collection.IObservable>
---@field private _all_observables      table<string, fc.types.collection.IObservable>
local Viewmodel = {}
Viewmodel.__index = Viewmodel
setmetatable(Viewmodel, { __index = BatchDisposable })

---@class fc.collection.Viewmodel.IProps
---@field public name                   string
---@field public filepath               ?string
---@field public verbose                ?boolean

---@param props                         fc.collection.Viewmodel.IProps
---@return fc.collection.Viewmodel
function Viewmodel.new(props)
  local self = setmetatable(BatchDisposable.new(), Viewmodel)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast self fc.collection.Viewmodel

  self._name = props.name ---@type string
  self._filepath = props.filepath ---@type string
  self._initial_values = {} ---@type table<string, any>
  self._unwatch = nil ---@type (fun():nil)|nil
  self._persistables = {} ---@type table<string, fc.types.collection.IObservable>
  self._verbose = not not props.verbose ---@type boolean
  self._all_observables = {} ---@type table<string, fc.types.collection.IObservable>

  return self
end

---@return nil
function Viewmodel:dispose()
  if self:is_disposed() then
    return
  end

  BatchDisposable.dispose(self)

  ---@type fc.types.collection.IDisposable[]
  local disposables = {}
  for _, disposable in pairs(self) do
    if is.disposable(disposable) then
      ---@cast disposable fc.types.collection.IDisposable
      table.insert(disposables, disposable)
    end
  end

  if self._unwatch then
    self._unwatch()
    self._unwatch = nil
  end

  BatchDisposable.dispose_all(disposables)
end

function Viewmodel:get_name()
  return self._name
end

function Viewmodel:get_filepath()
  return self._filepath
end

---@return table<string, any>
function Viewmodel:snapshot()
  local data = {}
  for key, observable in pairs(self._persistables) do
    if is.observable(observable) then
      ---@cast observable fc.types.collection.IObservable
      data[key] = observable:snapshot()
    end
  end
  return data
end

---@return table<string, any>
function Viewmodel:snapshot_all()
  local data = {}
  for key, observable in pairs(self._all_observables) do
    if is.observable(observable) then
      ---@cast observable fc.types.collection.IObservable
      data[key] = observable:snapshot()
    end
  end
  return data
end

---@param name string
---@param observable fc.types.collection.IObservable
---@param persistable boolean
---@param auto_save boolean
function Viewmodel:register(name, observable, persistable, auto_save)
  if persistable then
    self._persistables[name] = observable
  end

  self[name] = observable
  self._all_observables[name] = observable

  if auto_save then
    self._initial_values[name] = observable:snapshot()
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
      from = "fc.collection.viewmodel",
      subject = "save",
      message = "The filepath not specified",
      details = { name = self._name },
    })
    return
  end

  local data = self:snapshot() ---@type table
  fs.write_json(filepath, data, true)
end

---@param opts                          ?{ silent_on_notfound?: boolean }
---@return boolean  Indicate whether if the content loaded is different with current data.
function Viewmodel:load(opts)
  opts = opts or {}
  local silent_on_notfound = not not opts.silent_on_notfound ---@type boolean

  local filepath = self._filepath ---@type string|nil
  if filepath == nil then
    if not silent_on_notfound then
      reporter.error({
        from = "fc.collection.viewmodel",
        subject = "load",
        message = "The filepath not specified",
        details = { name = self._name, filepath = filepath },
      })
    end
    return false
  end

  if not path.is_exist(filepath) then
    if not silent_on_notfound then
      reporter.error({
        from = "fc.collection.viewmodel",
        subject = "load",
        message = "The filepath not exist",
        details = { name = self._name, filepath = filepath },
      })
    end
    return false
  end

  local data = fs.read_json({ filepath = filepath, silent_on_bad_path = true })
  if type(data) ~= "table" then
    if data ~= nil then
      reporter.warn({
        from = "fc.collection.viewmodel",
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
    if value ~= nil and is.observable(observable) then
      self._initial_values[key] = value
      has_changed = observable:next(value) or has_changed
    end
  end
  return has_changed
end

---@param params                        ?fc.types.collection.viewmodel.IAutoReloadParams
---@return nil
function Viewmodel:auto_reload(params)
  params = params or {}
  ---@cast params fc.types.collection.viewmodel.IAutoReloadParams

  local on_changed = params.on_changed or util.noop ---@type fun(): nil

  if self._unwatch ~= nil then
    return
  end

  local filepath = self._filepath ---@type string|nil
  if filepath == nil then
    reporter.error({
      from = "fc.collection.viewmodel",
      subject = "auto_reload",
      message = "The filepath not specified",
      details = { name = self._name, params, params },
    })
    return false
  end

  local unwatch = fs.watch_file({
    filepath = filepath,
    on_event = function(p, event)
      if type(event) == "table" and event.change == true then
        local has_changed = self:load()
        if has_changed then
          vim.schedule(on_changed)
          if self._verbose then
            reporter.info({
              from = "fc.collection.viewmodel",
              subject = "auto_reload",
              message = "auto reloaded.",
              details = { name = self._name, filepath = p },
              --details = { name = self._name, filepath = filepath, event = event },
            })
          end
        end
      end
    end,
    on_error = function(p, err)
      reporter.error({
        from = "fc.collection.viewmodel",
        subject = "auto_reload",
        message = "Failed!",
        details = { err = err, name = self._name, filepath = p },
      })
    end,
  })
  self._unwatch = unwatch
end

return Viewmodel
