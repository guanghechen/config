local BatchDisposable = require("guanghechen.disposable.BatchDisposable")
local Subscriber = require("guanghechen.subscriber.Subscriber")

---@class guanghechen.viewmodel.Viewmodel.util
local util = {
  disposable = require("guanghechen.util.disposable"),
  observable = require("guanghechen.util.observable"),
  fs = require("guanghechen.util.fs"),
}

---@class guanghechen.viewmodel.Viewmodel.IOptions
---@field public name string
---@field public filepath string

---@class guanghechen.viewmodel.Viewmodel : guanghechen.types.IViewmodel
---@field private _name string
---@field private _filepath string
local Viewmodel = {}
Viewmodel.__index = Viewmodel
setmetatable(Viewmodel, { __index = BatchDisposable })

---@param opts guanghechen.viewmodel.Viewmodel.IOptions
---@return guanghechen.viewmodel.Viewmodel
function Viewmodel.new(opts)
  local self = setmetatable(BatchDisposable.new(), Viewmodel)

  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast self guanghechen.viewmodel.Viewmodel

  ---@type string
  self._name = opts.name

  ---@type string
  self._filepath = opts.filepath

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
    if util.disposable(disposable) then
      ---@cast disposable guanghechen.types.IDisposable
      table.insert(disposables, disposable)
    end
  end

  util.disposable.disposeAll(disposables)
end

function Viewmodel:get_name()
  return self._name
end

---@return table<string, any>
function Viewmodel:get_snapshot()
  local data = {}
  for key, observable in pairs(self) do
    if util.observable.isObservable(observable) then
      ---@cast observable guanghechen.types.IObservable
      data[key] = observable:get_snapshot()
    end
  end
  return data
end

---@param name string
---@param observable guanghechen.types.IObservable
---@param autosave boolean
function Viewmodel:register(name, observable, autosave)
  if autosave then
    local first = true
    local current = self
    local subscriber = Subscriber.new({
      onNext = function()
        if first then
          first = false
        else
          current:save()
        end
      end,
    })
    observable:subscribe(subscriber)
  end

  self[name] = observable
  return self
end

function Viewmodel:save()
  local data = self:get_snapshot()
  local ok_to_encode_json, json_text = pcall(vim.json.encode, data)
  if not ok_to_encode_json then
    vim.notify("[Viewmodel:(" .. self._name .. ")] Failed to encode json data:" .. vim.inspect(data))
    return
  end

  vim.fn.mkdir(vim.fn.fnamemodify(self._filepath, ":p:h"), "p")
  local ok_to_save_json, result = pcall(vim.fn.writefile, { json_text }, self._filepath)
  if not ok_to_save_json then
    vim.notify("[Viewmodel:(" .. self._name .. ")] Failed to save json:" .. vim.inspect(data) .. "\n\n" .. result)
  end
end

function Viewmodel:load()
  local ok_to_load_json, json_text = pcall(util.fs.read_file, self._filepath)
  if not ok_to_load_json then
    vim.notify("[Viewmodel:(" .. self._name .. ")] Failed to read file:" .. self._filepath)
  end

  if json_text == nil then
    return
  end

  local ok_to_decode_json, data = pcall(vim.json.decode, json_text)
  if not ok_to_decode_json then
    vim.notify("[Viewmodel:(" .. self._name .. ")] Failed to decode json:" .. vim.inspect(json_text))
  end

  if type(data) ~= "table" then
    vim.notify("[Viewmodel:(" .. self._name .. ")] Bad json, not a table:" .. vim.inspect(json_text))
  end

  for key, item in pairs(data) do
    local observable = self[key]
    if item ~= nil and util.observable.isObservable(observable) then
      observable.next(item)
    end
  end
end

return Viewmodel
