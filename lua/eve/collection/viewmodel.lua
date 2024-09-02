local BatchDisposable = require("eve.collection.batch_disposable")
local Disposable = require("eve.collection.disposable")
local Subscriber = require("eve.collection.subscriber")
local fs = require("eve.std.fs")
local is = require("eve.std.is")
local path = require("eve.std.path")
local util = require("eve.std.util")
local reporter = require("eve.std.reporter")

---@class eve.collection.Viewmodel : eve.types.collection.IViewmodel
---@field private _name                 string
---@field private _filepath             string|nil
---@field private _unwatch              (fun():nil)|nil
---@field private _verbose              boolean
---@field private _persistables         table<string, eve.types.collection.IObservable>
---@field private _all_observables      table<string, eve.types.collection.IObservable>
local Viewmodel = {}
Viewmodel.__index = Viewmodel
setmetatable(Viewmodel, { __index = BatchDisposable })

---@class eve.collection.Viewmodel.IProps
---@field public name                   string
---@field public filepath               ?string
---@field public verbose                ?boolean

---@param props                         eve.collection.Viewmodel.IProps
---@return eve.collection.Viewmodel
function Viewmodel.new(props)
  local self = setmetatable(BatchDisposable.new(), Viewmodel)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast self eve.collection.Viewmodel

  self._name = props.name ---@type string
  self._filepath = props.filepath ---@type string
  self._unwatch = nil ---@type (fun():nil)|nil
  self._persistables = {} ---@type table<string, eve.types.collection.IObservable>
  self._verbose = not not props.verbose ---@type boolean
  self._all_observables = {} ---@type table<string, eve.types.collection.IObservable>

  return self
end

---@return nil
function Viewmodel:dispose()
  if self:is_disposed() then
    return
  end

  BatchDisposable.dispose(self)

  ---@type eve.types.collection.IDisposable[]
  local disposables = {}
  for _, disposable in pairs(self) do
    if is.disposable(disposable) then
      ---@cast disposable eve.types.collection.IDisposable
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
      ---@cast observable eve.types.collection.IObservable
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
      ---@cast observable eve.types.collection.IObservable
      data[key] = observable:snapshot()
    end
  end
  return data
end

---@param name string
---@param observable eve.types.collection.IObservable
---@param persistable boolean
---@param auto_save boolean
function Viewmodel:register(name, observable, persistable, auto_save)
  if persistable then
    self._persistables[name] = observable
  end

  self[name] = observable
  self._all_observables[name] = observable

  if auto_save then
    local subscriber = Subscriber.new({
      on_next = function()
        self:save()
      end,
    })
    local unsubscribable = observable:subscribe(subscriber, true)
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
      from = "eve.collection.viewmodel",
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
        from = "eve.collection.viewmodel",
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
        from = "eve.collection.viewmodel",
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
        from = "eve.collection.viewmodel",
        subject = "load",
        message = "Bad json, not a table",
        details = { name = self._name, data = data },
      })
    end
    return false
  end

  local has_changed = false ---@type boolean
  for key, value in pairs(data) do
    if has_changed then
      break
    end

    local observable = self[key]
    if value ~= nil and is.observable(observable) then
      has_changed = observable:next(value) or has_changed
    end
  end
  return has_changed
end

---@param params                        ?eve.types.collection.viewmodel.IAutoReloadParams
---@return nil
function Viewmodel:auto_reload(params)
  params = params or {}
  ---@cast params eve.types.collection.viewmodel.IAutoReloadParams

  local on_changed = params.on_changed or util.noop ---@type fun(): nil

  if self._unwatch ~= nil then
    return
  end

  local filepath = self._filepath ---@type string|nil
  if filepath == nil then
    reporter.error({
      from = "eve.collection.viewmodel",
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
              from = "eve.collection.viewmodel",
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
        from = "eve.collection.viewmodel",
        subject = "auto_reload",
        message = "Failed!",
        details = { err = err, name = self._name, filepath = p },
      })
    end,
  })
  self._unwatch = unwatch
end

return Viewmodel