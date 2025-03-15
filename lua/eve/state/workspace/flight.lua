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
---@field public ai                     eve.collection.IObservable -- boolean>
---@field public ai_provider            eve.collection.IObservable -- eve.e.AiProvider>
---@field public autoformat             eve.collection.IObservable -- boolean>
---@field public autoload               eve.collection.IObservable -- boolean>
---@field public autosave               eve.collection.IObservable -- boolean>
---@field public devmode                eve.collection.IObservable -- boolean>
---
---@field public dressing_hipairs       eve.collection.IObservable -- boolean>
---@field public dressing_illumniate    eve.collection.IObservable -- boolean>
---@field public dressing_input         eve.collection.IObservable -- boolean>
---@field public dressing_select        eve.collection.IObservable -- boolean>
---@field public dressing_winsep_fixed  eve.collection.IObservable -- boolean>
---@field public dressing_winsep_float  eve.collection.IObservable -- boolean>
---
---@field public gitdiff_expand_all     eve.collection.IObservable -- boolean>

---@class eve.state.flight : eve.state.flight.state
---@field public defaults               fun(): eve.state.flight.data
---@field public dump                   fun(): eve.state.flight.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.flight.data
local M = {}

---@return eve.state.flight.data
function M.defaults()
  local workspace = eve.path.workspace() ---@type string
  local is_home_config_dir = workspace == eve.env.HOME_NVIM_CONFIG ---@type boolean
  local is_git_repo = eve.path.is_repo_git() ---@type boolean
  local is_thirdparty = eve.path.is_repo_thirdparty() ---@type boolean
  local is_playground = eve.path.is_repo_playground() ---@type boolean
  local is_personal_public = eve.path.is_repo_personal_public() ---@type boolean

  ---@type eve.state.flight.data
  return {
    ai = is_thirdparty or is_playground or is_personal_public,
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
    if type(data.ai_provider) == "string" and vim.list_contains(eve.setting.ai_providers, data.ai_provider) then
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
  ---@type eve.state.flight.data
  return {
    ai = M.ai:snapshot(),
    ai_provider = M.ai_provider:snapshot(),
    autoformat = M.autoformat:snapshot(),
    autoload = M.autoload:snapshot(),
    autosave = M.autosave:snapshot(),
    devmode = M.devmode:snapshot(),

    dressing_hipairs = M.dressing_hipairs:snapshot(),
    dressing_illumniate = M.dressing_illumniate:snapshot(),
    dressing_input = M.dressing_input:snapshot(),
    dressing_select = M.dressing_select:snapshot(),
    dressing_winsep_fixed = M.dressing_winsep_fixed:snapshot(),
    dressing_winsep_float = M.dressing_winsep_float:snapshot(),

    gitdiff_expand_all = M.gitdiff_expand_all:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.flight.data

  M.ai:next(data.ai)
  M.ai_provider:next(data.ai_provider)
  M.autoformat:next(data.autoformat)
  M.autoload:next(data.autoload)
  M.autosave:next(data.autosave)
  M.devmode:next(data.devmode)

  M.dressing_hipairs:next(data.dressing_hipairs)
  M.dressing_illumniate:next(data.dressing_illumniate)
  M.dressing_input:next(data.dressing_input)
  M.dressing_select:next(data.dressing_select)
  M.dressing_winsep_fixed:next(data.dressing_winsep_fixed)
  M.dressing_winsep_float:next(data.dressing_winsep_float)

  M.gitdiff_expand_all:next(data.gitdiff_expand_all)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.state.flight.data
M.ai = eve.col.Observable.from_value(_defaults.ai)
M.ai_provider = eve.col.Observable.from_value(_defaults.ai_provider)
M.autoformat = eve.col.Observable.from_value(_defaults.autoformat)
M.autoload = eve.col.Observable.from_value(_defaults.autoload)
M.autosave = eve.col.Observable.from_value(_defaults.autosave)
M.devmode = eve.col.Observable.from_value(_defaults.devmode)

M.dressing_hipairs = eve.col.Observable.from_value(_defaults.dressing_hipairs)
M.dressing_illumniate = eve.col.Observable.from_value(_defaults.dressing_illumniate)
M.dressing_input = eve.col.Observable.from_value(_defaults.dressing_input)
M.dressing_select = eve.col.Observable.from_value(_defaults.dressing_select)
M.dressing_winsep_fixed = eve.col.Observable.from_value(_defaults.dressing_winsep_fixed)
M.dressing_winsep_float = eve.col.Observable.from_value(_defaults.dressing_winsep_float)

M.gitdiff_expand_all = eve.col.Observable.from_value(_defaults.gitdiff_expand_all)

return M
