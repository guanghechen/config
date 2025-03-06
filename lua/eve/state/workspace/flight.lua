local env = require("eve.builtin.env")
local path = require("eve.builtin.path")
local Observable = require("eve.collection.observable")
local setting = require("eve.constant.setting")

---@class eve.state.flight.data
---@field public ai                     boolean
---@field public ai_provider            eve.e.AiProvider
---@field public autoformat             boolean
---@field public autoload               boolean
---@field public autosave               boolean
---@field public devmode                boolean
---
---@field public dressing_hipairs       boolean
---@field public dressing_illumniate    boolean
---@field public dressing_input         boolean
---@field public dressing_select        boolean
---@field public dressing_winsep_fixed  boolean
---@field public dressing_winsep_float  boolean
---
---@field public gitdiff_expand_all     boolean

---@class eve.state.flight.state
---@field public ai                     eve.collection.IObservable
---@field public ai_provider            eve.collection.IObservable
---@field public autoformat             eve.collection.IObservable
---@field public autoload               eve.collection.IObservable
---@field public autosave               eve.collection.IObservable
---@field public devmode                eve.collection.IObservable
---
---@field public dressing_hipairs       eve.collection.IObservable
---@field public dressing_illumniate    eve.collection.IObservable
---@field public dressing_input         eve.collection.IObservable
---@field public dressing_select        eve.collection.IObservable
---@field public dressing_winsep_fixed  eve.collection.IObservable
---@field public dressing_winsep_float  eve.collection.IObservable
---
---@field public gitdiff_expand_all     eve.collection.IObservable

---@class eve.state.flight
---@field public defaults               fun(): eve.state.flight.data
---@field public dump                   fun(): eve.state.flight.data
---@field public load                   fun(data: unknown): eve.state.flight.state
---@field public normalize              fun(data: unknown): eve.state.flight.data
local M = {}

local _state = nil ---@type eve.state.flight.state | nil

---@return eve.state.flight.data
function M.defaults()
  local workspace = path.workspace() ---@type string
  local is_home_config_dir = workspace == env.HOME_NVIM_CONFIG ---@type boolean
  local is_git_repo = path.is_git_repo() ---@type boolean
  local is_sourcecode = path.is_sourcecode() ---@type boolean
  local is_playground = path.is_playground() ---@type boolean

  ---@type eve.state.flight.data
  return {
    ai = is_home_config_dir or is_sourcecode or is_playground,
    ai_provider = "copilot",
    autoformat = is_git_repo,
    autoload = false,
    autosave = is_git_repo,
    devmode = is_home_config_dir,

    dressing_hipairs = true,
    dressing_illumniate = true,
    dressing_input = true,
    dressing_select = true,
    dressing_winsep_fixed = true,
    dressing_winsep_float = false,

    gitdiff_expand_all = is_git_repo,
  }
end

---@param data                        any
---@return eve.state.flight.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.flight.data
  if type(data) == "table" then
    if type(data.ai) == "boolean" then
      resolved.ai = data.ai
    end
    if type(data.ai_provider) == "string" and vim.list_contains(setting.ai_providers, data.ai_provider) then
      resolved.ai_provider = data.ai_provider
    end
    if type(data.autoformat) == "boolean" then
      resolved.autoformat = data.autoformat
    end
    if type(data.autoload) == "boolean" then
      resolved.autoload = data.autoload
    end
    if type(data.autosave) == "boolean" then
      resolved.autosave = data.autosave
    end
    if type(data.devmode) == "boolean" then
      resolved.devmode = data.devmode
    end

    if type(data.dressing_hipairs) == "boolean" then
      resolved.dressing_hipairs = data.dressing_hipairs
    end
    if type(data.dressing_illumniate) == "boolean" then
      resolved.dressing_illumniate = data.dressing_illumniate
    end
    if type(data.dressing_input) == "boolean" then
      resolved.dressing_input = data.dressing_input
    end
    if type(data.dressing_select) == "boolean" then
      resolved.dressing_select = data.dressing_select
    end
    if type(data.dressing_winsep_fixed) == "boolean" then
      resolved.dressing_winsep_fixed = data.dressing_winsep_fixed
    end
    if type(data.dressing_winsep_float) == "boolean" then
      resolved.dressing_winsep_float = data.dressing_winsep_float
    end

    if type(data.gitdiff_expand_all) == "boolean" then
      resolved.gitdiff_expand_all = data.gitdiff_expand_all
    end
  end
  return resolved
end

---@return eve.state.flight.data
function M.dump()
  if _state == nil then
    return M.defaults()
  end

  ---@type eve.state.flight.data
  return {
    ai = _state.ai:snapshot(),
    ai_provider = _state.ai_provider:snapshot(),
    autoformat = _state.autoformat:snapshot(),
    autoload = _state.autoload:snapshot(),
    autosave = _state.autosave:snapshot(),
    devmode = _state.devmode:snapshot(),

    dressing_hipairs = _state.dressing_hipairs:snapshot(),
    dressing_illumniate = _state.dressing_illumniate:snapshot(),
    dressing_input = _state.dressing_input:snapshot(),
    dressing_select = _state.dressing_select:snapshot(),
    dressing_winsep_fixed = _state.dressing_winsep_fixed:snapshot(),
    dressing_winsep_float = _state.dressing_winsep_float:snapshot(),

    gitdiff_expand_all = _state.gitdiff_expand_all:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.flight.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.flight.data

  if _state == nil then
    ---@type eve.state.flight.state
    _state = {
      ai = Observable.from_value(data.ai),
      ai_provider = Observable.from_value(data.ai_provider),
      autoformat = Observable.from_value(data.autoformat),
      autoload = Observable.from_value(data.autoload),
      autosave = Observable.from_value(data.autosave),
      devmode = Observable.from_value(data.devmode),

      dressing_hipairs = Observable.from_value(data.dressing_hipairs),
      dressing_illumniate = Observable.from_value(data.dressing_illumniate),
      dressing_input = Observable.from_value(data.dressing_input),
      dressing_select = Observable.from_value(data.dressing_select),
      dressing_winsep_fixed = Observable.from_value(data.dressing_winsep_fixed),
      dressing_winsep_float = Observable.from_value(data.dressing_winsep_float),

      gitdiff_expand_all = Observable.from_value(data.gitdiff_expand_all),
    }
    return _state
  end

  _state.ai:next(data.ai)
  _state.ai_provider:next(data.ai_provider)
  _state.autoformat:next(data.autoformat)
  _state.autoload:next(data.autoload)
  _state.autosave:next(data.autosave)
  _state.devmode:next(data.devmode)

  _state.dressing_hipairs:next(data.dressing_hipairs)
  _state.dressing_illumniate:next(data.dressing_illumniate)
  _state.dressing_input:next(data.dressing_input)
  _state.dressing_select:next(data.dressing_select)
  _state.dressing_winsep_fixed:next(data.dressing_winsep_fixed)
  _state.dressing_winsep_float:next(data.dressing_winsep_float)

  _state.gitdiff_expand_all:next(data.gitdiff_expand_all)
  return _state
end

return M
