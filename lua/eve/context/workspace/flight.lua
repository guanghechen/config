---@class eve.context.flight.data
---@field public ai                     boolean
---@field public autoformat             boolean
---@field public autoload               boolean
---@field public autosave               boolean
---@field public devmode                boolean
---
---@field public dressing_clipboard     boolean
---@field public dressing_hipairs       boolean
---@field public dressing_illumniate    boolean
---@field public dressing_input         boolean
---@field public dressing_select        boolean
---@field public dressing_winsep        boolean
---
---@field public gitdiff_expand_all     boolean

---@class eve.context.flight.state
---@field public ai                     std.collection.IObservable
---@field public autoformat             std.collection.IObservable
---@field public autoload               std.collection.IObservable
---@field public autosave               std.collection.IObservable
---@field public devmode                std.collection.IObservable
---
---@field public dressing_clipboard     std.collection.IObservable
---@field public dressing_hipairs       std.collection.IObservable
---@field public dressing_illumniate    std.collection.IObservable
---@field public dressing_input         std.collection.IObservable
---@field public dressing_select        std.collection.IObservable
---@field public dressing_winsep        std.collection.IObservable
---
---@field public gitdiff_expand_all     std.collection.IObservable

---@class eve.context.flight : eve.context.flight.state
---@field public defaults               fun(): eve.context.flight.data
---@field public dump                   fun(): eve.context.flight.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.flight.data
local M = {}

---@return eve.context.flight.data
function M.defaults()
  local workspace = std.path.workspace() ---@type string
  local is_home_config_dir = workspace == std.env.HOME_NVIM_CONFIG ---@type boolean
  local is_git_repo = std.path.is_git_repo() ---@type boolean
  local is_thirdparty = std.path.is_repo_thirdparty() ---@type boolean
  local is_playground = std.path.is_repo_playground() ---@type boolean
  local is_personal_public = std.path.is_repo_personal_public() ---@type boolean

  ---@type eve.context.flight.data
  return {
    ai = is_thirdparty or is_playground or is_personal_public,
    autoformat = is_git_repo,
    autoload = false,
    autosave = is_git_repo,
    devmode = is_home_config_dir,

    dressing_clipboard = false,
    dressing_hipairs = false,
    dressing_illumniate = true,
    dressing_input = true,
    dressing_select = true,
    dressing_winsep = true,

    gitdiff_expand_all = false,
  }
end

---@param data                        any
---@return eve.context.flight.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.flight.data
  if type(data) == "table" then
    if type(data.ai) == "boolean" then
      resolved.ai = data.ai
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

    if type(data.dressing_clipboard) == "boolean" then
      resolved.dressing_clipboard = data.dressing_clipboard
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

---@return eve.context.flight.data
function M.dump()
  ---@type eve.context.flight.data
  return {
    ai = M.ai:snapshot(),
    autoformat = M.autoformat:snapshot(),
    autoload = M.autoload:snapshot(),
    autosave = M.autosave:snapshot(),
    devmode = M.devmode:snapshot(),

    dressing_clipboard = M.dressing_clipboard:snapshot(),
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
  local data = M.normalize(raw_data) ---@type eve.context.flight.data

  M.ai:next(data.ai)
  M.autoformat:next(data.autoformat)
  M.autoload:next(data.autoload)
  M.autosave:next(data.autosave)
  M.devmode:next(data.devmode)

  M.dressing_clipboard:next(data.dressing_clipboard)
  M.dressing_hipairs:next(data.dressing_hipairs)
  M.dressing_illumniate:next(data.dressing_illumniate)
  M.dressing_input:next(data.dressing_input)
  M.dressing_select:next(data.dressing_select)
  M.dressing_winsep:next(data.dressing_winsep)

  M.gitdiff_expand_all:next(data.gitdiff_expand_all)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.flight.data
M.ai = std.Observable.from_value(_defaults.ai)
M.autoformat = std.Observable.from_value(_defaults.autoformat)
M.autoload = std.Observable.from_value(_defaults.autoload)
M.autosave = std.Observable.from_value(_defaults.autosave)
M.devmode = std.Observable.from_value(_defaults.devmode)

M.dressing_clipboard = std.Observable.from_value(_defaults.dressing_clipboard)
M.dressing_hipairs = std.Observable.from_value(_defaults.dressing_hipairs)
M.dressing_illumniate = std.Observable.from_value(_defaults.dressing_illumniate)
M.dressing_input = std.Observable.from_value(_defaults.dressing_input)
M.dressing_select = std.Observable.from_value(_defaults.dressing_select)
M.dressing_winsep = std.Observable.from_value(_defaults.dressing_winsep, std.fn.falsy)

M.gitdiff_expand_all = std.Observable.from_value(_defaults.gitdiff_expand_all)

return M
