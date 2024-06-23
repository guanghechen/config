local BatchDisposable = require("guanghechen.disposable.BatchDisposable")
local Disposable = require("guanghechen.disposable.Disposable")
local Subscriber = require("guanghechen.subscriber.Subscriber")
local util_disposable = require("guanghechen.util.disposable")
local util_observable = require("guanghechen.util.observable")
local util_fs = require("guanghechen.util.fs")
local util_json = require("fml.core.json")
local util_reporter = require("guanghechen.util.reporter")

---@class guanghechen.viewmodel.Viewmodel.IOptions
---@field public name string
---@field public filepath string

---@class guanghechen.viewmodel.Viewmodel : guanghechen.types.IViewmodel
---@field private _name string
---@field private _filepath string
---@field private _initial_values table<string, any>
---@field private _unwatch (fun():nil)|nil
---@field private _persistable_observables table<string, guanghechen.types.IObservable>
---@field private _all_observables table<string, guanghechen.types.IObservable>
local Viewmodel = {}
Viewmodel.__index = Viewmodel
setmetatable(Viewmodel, { __index = BatchDisposable })

---@param opts guanghechen.viewmodel.Viewmodel.IOptions
---@return guanghechen.viewmodel.Viewmodel
function Viewmodel.new(opts)
  local self = setmetatable(BatchDisposable.new(), Viewmodel)

  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast self guanghechen.viewmodel.Viewmodel

  self._name = opts.name ---@type string
  self._filepath = opts.filepath ---@type string
  self._initial_values = {} ---@type table<string, any>
  self._unwatch = nil ---@type (fun():nil)|nil
  self._persistable_observables = {} ---@type table<string, guanghechen.types.IObservable>
  self._all_observables = {} ---@type table<string, guanghechen.types.IObservable>

  return self
end

---@return nil
function Viewmodel:dispose()
  if self:isDisposed() then
    return
  end

  BatchDisposable.dispose(self)

  ---@type guanghechen.types.IDisposable[]
  local disposables = {}
  for _, disposable in pairs(self) do
    if util_disposable(disposable) then
      ---@cast disposable guanghechen.types.IDisposable
      table.insert(disposables, disposable)
    end
  end

  if self._unwatch then
    self._unwatch()
    self._unwatch = nil
  end

  util_disposable.disposeAll(disposables)
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
  for key, observable in pairs(self._persistable_observables) do
    if util_observable.is_observable(observable) then
      ---@cast observable guanghechen.types.IObservable
      data[key] = observable:get_snapshot()
    end
  end
  return data
end

---@return table<string, any>
function Viewmodel:get_snapshot_all()
  local data = {}
  for key, observable in pairs(self._all_observables) do
    if util_observable.is_observable(observable) then
      ---@cast observable guanghechen.types.IObservable
      data[key] = observable:get_snapshot()
    end
  end
  return data
end

---@param name string
---@param observable guanghechen.types.IObservable
---@param persistable boolean
---@param auto_save boolean
function Viewmodel:register(name, observable, persistable, auto_save)
  if persistable then
    self._persistable_observables[name] = observable
  end

  self[name] = observable
  self._all_observables[name] = observable

  if auto_save then
    self._initial_values[name] = observable:get_snapshot()
    local subscriber = Subscriber.new({
      onNext = function(next_value)
        if not observable.equals(self._initial_values[name], next_value) then
          self._initial_values[name] = next_value
          self:save()
        end
      end,
    })
    local unsubscribable = observable:subscribe(subscriber)
    self:registerDisposable(Disposable.new(function()
      unsubscribable:unsubscribe()
    end))
  end

  return self
end

function Viewmodel:save()
  local data = self:get_snapshot()
  local ok_to_encode_json, json_text = pcall(util_json.stringify_prettier, data)
  if not ok_to_encode_json then
    util_reporter.warn({
      from = self._name,
      subject = "Viewmodel:save",
      message = "Failed to encode json data",
      details = data,
    })
    return
  end

  vim.fn.mkdir(vim.fn.fnamemodify(self._filepath, ":p:h"), "p")

  local file = io.open(self._filepath, "w")
  if not file then
    util_reporter.warn({
      from = self._name,
      subject = "Viewmodel:save",
      message = "Failed to save json",
      details = data,
    })
    return
  end

  file:write(json_text)
  file:close()
end

function Viewmodel:load()
  local ok_to_load_json, json_text = pcall(util_fs.read_file, self._filepath)
  if not ok_to_load_json then
    return
  end

  if json_text == nil then
    return
  end

  local ok_to_decode_json, data = pcall(vim.json.decode, json_text)
  if not ok_to_decode_json then
    util_reporter.warn({
      from = self._name,
      subject = "Viewmodel:load",
      message = "Failed to decode json",
      details = json_text,
    })
    return
  end

  if type(data) ~= "table" then
    util_reporter.warn({
      from = self._name,
      subject = "Viewmodel:load",
      message = "Bad json, not a table",
      details = json_text,
    })
    return
  end

  for key, value in pairs(data) do
    local observable = self[key]
    if value ~= nil and util_observable.is_observable(observable) then
      self._initial_values[key] = value
      observable:next(value)
    end
  end
end

function Viewmodel:auto_reload()
  if self._unwatch ~= nil then
    return
  end

  local unwatch = util_fs.watch_file({
    filepath = self._filepath,
    on_event = function(filepath, event)
      if type(event) == "table" and event.change == true then
        self:load()
        util_reporter.info({
          from = self._name,
          subject = "Viewmodel:auto_reload",
          message = "auto reloaded.",
          -- details = { filepath = filepath, event = event, },
        })
      end
    end,
    on_error = function(filepath, err)
      util_reporter.error({
        from = self._name,
        subject = "Viewmodel:auto_reload",
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
