local BatchDisposable = require("fml.collection.batch_disposable")
local Disposable = require("fml.collection.disposable")
local Subscriber = require("fml.collection.subscriber")
local is_disposable = require("fml.fn.is_disposable")
local is_observable = require("fml.fn.is_observable")
local dispose_all = require("fml.fn.dispose_all")
local fs = require("fml.core.fs")
local json = require("fml.core.json")
local reporter = require("fml.core.reporter")

---@class fml.collection.Viewmodel : fml.types.collection.IViewmodel
---@field private _name                 string
---@field private _filepath             string
---@field private _initial_values       table<string, any>
---@field private _unwatch              (fun():nil)|nil
---@field private _persistables         table<string, fml.types.collection.IObservable>
---@field private _all_observables      table<string, fml.types.collection.IObservable>
local Viewmodel = {}
Viewmodel.__index = Viewmodel
setmetatable(Viewmodel, { __index = BatchDisposable })

---@class fml.collection.Viewmodel.IProps
---@field public name                   string
---@field public filepath               string

---@param props fml.collection.Viewmodel.IProps
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
  local data = self:get_snapshot()
  local ok_to_encode_json, json_text = pcall(json.stringify_prettier, data)
  if not ok_to_encode_json then
    reporter.warn({
      from = "fml.collection.viewmodel",
      subject = "save",
      message = "Failed to encode json data",
      details = data,
    })
    return
  end

  vim.fn.mkdir(vim.fn.fnamemodify(self._filepath, ":p:h"), "p")

  local file = io.open(self._filepath, "w")
  if not file then
    reporter.warn({
      from = "fml.collection.viewmodel",
      subject = "save",
      message = "Failed to save json",
      details = data,
    })
    return
  end

  file:write(json_text)
  file:close()
end

function Viewmodel:load()
  local ok_to_load_json, json_text = pcall(fs.read_file, self._filepath)
  if not ok_to_load_json then
    return
  end

  if json_text == nil then
    return
  end

  local ok_to_decode_json, data = pcall(vim.json.decode, json_text)
  if not ok_to_decode_json then
    reporter.warn({
      from = "fml.collection.viewmodel",
      subject = "load",
      message = "Failed to decode json",
      details = json_text,
    })
    return
  end

  if type(data) ~= "table" then
    reporter.warn({
      from = "fml.collection.viewmodel",
      subject = "load",
      message = "Bad json, not a table",
      details = json_text,
    })
    return
  end

  for key, value in pairs(data) do
    local observable = self[key]
    if value ~= nil and is_observable(observable) then
      self._initial_values[key] = value
      observable:next(value)
    end
  end
end

function Viewmodel:auto_reload()
  if self._unwatch ~= nil then
    return
  end

  local unwatch = fs.watch_file({
    filepath = self._filepath,
    on_event = function(filepath, event)
      if type(event) == "table" and event.change == true then
        self:load()
        reporter.info({
          from = "fml.collection.viewmodel",
          subject = "auto_reload",
          message = "auto reloaded.",
          details = { filepath = filepath },
          --details = { filepath = filepath, event = event },
        })
      end
    end,
    on_error = function(filepath, err)
      reporter.error({
        from = "fml.collection.viewmodel",
        subject = "auto_reload",
        message = "Failed!",
        details = {
          err = err,
          filepath = filepath,
        },
      })
    end,
  })
  self._unwatch = unwatch
end

return Viewmodel
