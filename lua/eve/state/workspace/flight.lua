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
---@field public dressing_winsep        boolean
---
---@field public gitdiff_expand_all     boolean

---@class eve.state.flight.state
---@field public ai                     eve.std.collection.IObservable -- boolean>
---@field public ai_provider            eve.std.collection.IObservable -- eve.e.AiProvider>
---@field public autoformat             eve.std.collection.IObservable -- boolean>
---@field public autoload               eve.std.collection.IObservable -- boolean>
---@field public autosave               eve.std.collection.IObservable -- boolean>
---@field public devmode                eve.std.collection.IObservable -- boolean>
---
---@field public dressing_hipairs       eve.std.collection.IObservable -- boolean>
---@field public dressing_illumniate    eve.std.collection.IObservable -- boolean>
---@field public dressing_input         eve.std.collection.IObservable -- boolean>
---@field public dressing_select        eve.std.collection.IObservable -- boolean>
---@field public dressing_winsep        eve.std.collection.IObservable -- boolean>
---
---@field public gitdiff_expand_all     eve.std.collection.IObservable -- boolean>

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
    dressing_winsep = true,

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
    if type(data.dressing_winsep) == "boolean" then
      resolved.dressing_winsep = data.dressing_winsep
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
    dressing_winsep = M.dressing_winsep:snapshot(),

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
  M.dressing_winsep:next(data.dressing_winsep)

  M.gitdiff_expand_all:next(data.gitdiff_expand_all)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.state.flight.data
M.ai = eve.std.Observable.from_value(_defaults.ai)
M.ai_provider = eve.std.Observable.from_value(_defaults.ai_provider)
M.autoformat = eve.std.Observable.from_value(_defaults.autoformat)
M.autoload = eve.std.Observable.from_value(_defaults.autoload)
M.autosave = eve.std.Observable.from_value(_defaults.autosave)
M.devmode = eve.std.Observable.from_value(_defaults.devmode)

M.dressing_hipairs = eve.std.Observable.from_value(_defaults.dressing_hipairs)
M.dressing_illumniate = eve.std.Observable.from_value(_defaults.dressing_illumniate)
M.dressing_input = eve.std.Observable.from_value(_defaults.dressing_input)
M.dressing_select = eve.std.Observable.from_value(_defaults.dressing_select)
M.dressing_winsep = eve.std.Observable.from_value(_defaults.dressing_winsep, eve.std.fn.falsy)

M.gitdiff_expand_all = eve.std.Observable.from_value(_defaults.gitdiff_expand_all)

return M
