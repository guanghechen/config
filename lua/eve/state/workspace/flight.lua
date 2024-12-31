local env = require("eve.lib.env")
local path = require("eve.lib.path")
local Observable = require("eve.lib.collection.observable")

---@class eve.state.flight.data
---@field public autoload               boolean
---@field public autosave               boolean
---@field public copilot                boolean
---@field public devmode                boolean
---
---@field public dressing_hipairs       boolean
---@field public dressing_winsep_fixed  boolean
---@field public dressing_winsep_float  boolean
---
---@field public lsp_inlay_hints        boolean
---@field public lsp_code_lens          boolean
---
---@field public spellcheck             boolean

---@class eve.state.flight.state
---@field public autoload               eve.lib.collection.IObservable
---@field public autosave               eve.lib.collection.IObservable
---@field public copilot                eve.lib.collection.IObservable
---@field public devmode                eve.lib.collection.IObservable
---
---@field public dressing_hipairs       eve.lib.collection.IObservable
---@field public dressing_winsep_fixed  eve.lib.collection.IObservable
---@field public dressing_winsep_float  eve.lib.collection.IObservable
---
---@field public lsp_inlay_hints        eve.lib.collection.IObservable
---@field public lsp_code_lens          eve.lib.collection.IObservable
---
---@field public spellcheck             eve.lib.collection.IObservable

---@class eve.state.flight
---@field public defaults               fun(): eve.state.flight.data
---@field public dump                   fun(): eve.state.flight.data
---@field public load                   fun(data: unknown): eve.state.flight.state
---@field public normalize              fun(data: unknown): eve.state.flight.data
local M = {}

local _state = nil ---@type eve.state.flight.state | nil

---@return eve.state.flight.data
function M.defaults()
  local is_home_config_dir = path.workspace() == env.HOME_NVIM_CONFIG ---@type boolean

  ---@type eve.state.flight.data
  return {
    autoload = false,
    autosave = true,
    copilot = is_home_config_dir,
    devmode = is_home_config_dir,

    dressing_hipairs = true,
    dressing_winsep_fixed = true,
    dressing_winsep_float = false,

    lsp_inlay_hints = true,
    lsp_code_lens = true,

    spellcheck = false,
  }
end

---@param data                        any
---@return eve.state.flight.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.flight.data
  if type(data) == "table" then
    if type(data.autoload) == "boolean" then
      resolved.autoload = data.autoload
    end
    if type(data.autosave) == "boolean" then
      resolved.autosave = data.autosave
    end
    if type(data.copilot) == "boolean" then
      resolved.copilot = data.copilot
    end
    if type(data.devmode) == "boolean" then
      resolved.devmode = data.devmode
    end

    if type(data.dressing_hipairs) == "boolean" then
      resolved.dressing_hipairs = data.dressing_hipairs
    end
    if type(data.dressing_winsep_fixed) == "boolean" then
      resolved.dressing_winsep_fixed = data.dressing_winsep_fixed
    end
    if type(data.dressing_winsep_float) == "boolean" then
      resolved.dressing_winsep_float = data.dressing_winsep_float
    end

    if type(data.lsp_inlay_hints) == "boolean" then
      resolved.lsp_inlay_hints = data.lsp_inlay_hints
    end
    if type(data.lsp_code_lens) == "boolean" then
      resolved.lsp_code_lens = data.lsp_code_lens
    end

    if type(data.spellcheck) == "boolean" then
      resolved.spellcheck = data.spellcheck
    end
  end

  ---@type eve.state.flight.data
  return resolved
end

---@return eve.state.flight.data
function M.dump()
  if _state == nil then
    ---@type eve.state.flight.data
    return M.defaults()
  end

  ---@type eve.state.flight.data
  return {
    autoload = _state.autoload:snapshot(),
    autosave = _state.autosave:snapshot(),
    copilot = _state.copilot:snapshot(),
    devmode = _state.devmode:snapshot(),

    dressing_hipairs = _state.dressing_hipairs:snapshot(),
    dressing_winsep_fixed = _state.dressing_winsep_fixed:snapshot(),
    dressing_winsep_float = _state.dressing_winsep_float:snapshot(),

    lsp_inlay_hints = _state.lsp_inlay_hints:snapshot(),
    lsp_code_lens = _state.lsp_code_lens:snapshot(),

    spellcheck = _state.spellcheck:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.flight.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.flight.data

  if _state == nil then
    ---@type eve.state.flight.state
    _state = {
      autoload = Observable.from_value(data.autoload),
      autosave = Observable.from_value(data.autosave),
      copilot = Observable.from_value(data.copilot),
      devmode = Observable.from_value(data.devmode),

      dressing_hipairs = Observable.from_value(data.dressing_hipairs),
      dressing_winsep_fixed = Observable.from_value(data.dressing_winsep_fixed),
      dressing_winsep_float = Observable.from_value(data.dressing_winsep_float),

      lsp_inlay_hints = Observable.from_value(data.lsp_inlay_hints),
      lsp_code_lens = Observable.from_value(data.lsp_code_lens),

      spellcheck = Observable.from_value(data.spellcheck),
    }
    return _state
  end

  _state.autoload:next(data.autoload)
  _state.autosave:next(data.autosave)
  _state.copilot:next(data.copilot)
  _state.devmode:next(data.devmode)

  _state.dressing_hipairs:next(data.dressing_hipairs)
  _state.dressing_winsep_fixed:next(data.dressing_winsep_fixed)
  _state.dressing_winsep_float:next(data.dressing_winsep_float)

  _state.lsp_inlay_hints:next(data.lsp_inlay_hints)
  _state.lsp_code_lens:next(data.lsp_code_lens)

  _state.spellcheck:next(data.spellcheck)
  return _state
end

return M
