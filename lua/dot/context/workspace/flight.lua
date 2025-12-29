---@class dot.context.flight.data
---@field public ai                     boolean
---@field public ai_nes                 boolean
---@field public autoformat             boolean
---@field public autoload               boolean
---@field public autosave               boolean
---@field public devmode                boolean
---
---@field public dressing_clipboard     boolean
---@field public dressing_dim           boolean
---@field public dressing_illuminate    boolean
---@field public dressing_image         boolean
---@field public dressing_indent        boolean
---@field public dressing_input         boolean
---@field public dressing_scroll        boolean
---@field public dressing_select        boolean
---@field public dressing_trailspace    boolean
---@field public dressing_ui_attach     boolean
---@field public dressing_virtcolumn    boolean
---@field public dressing_winsep        boolean
---
---@field public gitdiff_expand_all     boolean

---@class dot.context.flight.state
---@field public ai                     ark.c.Observable
---@field public ai_nes                 ark.c.Observable
---@field public autoformat             ark.c.Observable
---@field public autoload               ark.c.Observable
---@field public autosave               ark.c.Observable
---@field public devmode                ark.c.Observable
---
---@field public dressing_clipboard     ark.c.Observable
---@field public dressing_dim           ark.c.Observable
---@field public dressing_illuminate    ark.c.Observable
---@field public dressing_image         ark.c.Observable
---@field public dressing_indent        ark.c.Observable
---@field public dressing_input         ark.c.Observable
---@field public dressing_scroll        ark.c.Observable
---@field public dressing_select        ark.c.Observable
---@field public dressing_trailspace    ark.c.Observable
---@field public dressing_ui_attach     ark.c.Observable
---@field public dressing_virtcolumn    ark.c.Observable
---@field public dressing_winsep        ark.c.Observable
---
---@field public gitdiff_expand_all     ark.c.Observable

---@class dot.context.flight : dot.context.flight.state
---@field public defaults               fun(): dot.context.flight.data
---@field public dump                   fun(): dot.context.flight.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): dot.context.flight.data
local M = {}

---@return dot.context.flight.data
function M.defaults()
  local workspace = dot.path.workspace() ---@type string
  local is_home_config_dir = workspace == stl.env.HOME_NVIM_CONFIG ---@type boolean
  local is_git_repo = dot.path.is_git_repo() ---@type boolean
  local is_thirdparty = dot.path.is_repo_thirdparty() ---@type boolean
  local is_playground = dot.path.is_repo_playground() ---@type boolean
  local is_personal_public = dot.path.is_repo_personal_public() ---@type boolean

  ---@type dot.context.flight.data
  return {
    ai = is_thirdparty or is_playground or is_personal_public,
    ai_nes = false,
    autoformat = is_git_repo,
    autoload = false,
    autosave = is_git_repo,
    devmode = is_home_config_dir,

    dressing_clipboard = false,
    dressing_dim = false,
    dressing_illuminate = true,
    dressing_image = true,
    dressing_indent = true,
    dressing_input = true,
    dressing_scroll = true,
    dressing_select = true,
    dressing_trailspace = true,
    dressing_ui_attach = true,
    dressing_virtcolumn = true,
    dressing_winsep = true,

    gitdiff_expand_all = false,
  }
end

---@param data                          any
---@return dot.context.flight.data
function M.normalize(data)
  local resolved = M.defaults() ---@type dot.context.flight.data
  if type(data) == "table" then
    if type(data.ai) == "boolean" then
      resolved.ai = data.ai
    end
    if type(data.ai_nes) == "boolean" then
      resolved.ai_nes = data.ai_nes
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
    if type(data.dressing_dim) == "boolean" then
      resolved.dressing_dim = data.dressing_dim
    end
    if type(data.dressing_illuminate) == "boolean" then
      resolved.dressing_illuminate = data.dressing_illuminate
    end
    if type(data.dressing_image) == "boolean" then
      resolved.dressing_image = data.dressing_image
    end
    if type(data.dressing_indent) == "boolean" then
      resolved.dressing_indent = data.dressing_indent
    end
    if type(data.dressing_input) == "boolean" then
      resolved.dressing_input = data.dressing_input
    end
    if type(data.dressing_scroll) == "boolean" then
      resolved.dressing_scroll = data.dressing_scroll
    end
    if type(data.dressing_select) == "boolean" then
      resolved.dressing_select = data.dressing_select
    end
    if type(data.dressing_trailspace) == "boolean" then
      resolved.dressing_trailspace = data.dressing_trailspace
    end
    if type(data.dressing_ui_attach) == "boolean" then
      resolved.dressing_ui_attach = data.dressing_ui_attach
    end
    if type(data.dressing_virtcolumn) == "boolean" then
      resolved.dressing_virtcolumn = data.dressing_virtcolumn
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

---@return dot.context.flight.data
function M.dump()
  ---@type dot.context.flight.data
  return {
    ai = M.ai:snapshot(),
    ai_nes = M.ai_nes:snapshot(),
    autoformat = M.autoformat:snapshot(),
    autoload = M.autoload:snapshot(),
    autosave = M.autosave:snapshot(),
    devmode = M.devmode:snapshot(),

    dressing_clipboard = M.dressing_clipboard:snapshot(),
    dressing_dim = M.dressing_dim:snapshot(),
    dressing_illuminate = M.dressing_illuminate:snapshot(),
    dressing_image = M.dressing_image:snapshot(),
    dressing_indent = M.dressing_indent:snapshot(),
    dressing_input = M.dressing_input:snapshot(),
    dressing_scroll = M.dressing_scroll:snapshot(),
    dressing_select = M.dressing_select:snapshot(),
    dressing_trailspace = M.dressing_trailspace:snapshot(),
    dressing_ui_attach = M.dressing_ui_attach:snapshot(),
    dressing_virtcolumn = M.dressing_virtcolumn:snapshot(),
    dressing_winsep = M.dressing_winsep:snapshot(),

    gitdiff_expand_all = M.gitdiff_expand_all:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type dot.context.flight.data

  M.ai:next(data.ai)
  M.ai_nes:next(data.ai_nes)
  M.autoformat:next(data.autoformat)
  M.autoload:next(data.autoload)
  M.autosave:next(data.autosave)
  M.devmode:next(data.devmode)

  M.dressing_clipboard:next(data.dressing_clipboard)
  M.dressing_dim:next(data.dressing_dim)
  M.dressing_illuminate:next(data.dressing_illuminate)
  M.dressing_image:next(data.dressing_image)
  M.dressing_indent:next(data.dressing_indent)
  M.dressing_input:next(data.dressing_input)
  M.dressing_scroll:next(data.dressing_scroll)
  M.dressing_select:next(data.dressing_select)
  M.dressing_trailspace:next(data.dressing_trailspace)
  M.dressing_ui_attach:next(data.dressing_ui_attach)
  M.dressing_virtcolumn:next(data.dressing_virtcolumn)
  M.dressing_winsep:next(data.dressing_winsep)

  M.gitdiff_expand_all:next(data.gitdiff_expand_all)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type dot.context.flight.data
M.ai = ark.c.Observable.from_value(_defaults.ai)
M.ai_nes = ark.c.Observable.from_value(_defaults.ai_nes)
M.autoformat = ark.c.Observable.from_value(_defaults.autoformat)
M.autoload = ark.c.Observable.from_value(_defaults.autoload)
M.autosave = ark.c.Observable.from_value(_defaults.autosave)
M.devmode = ark.c.Observable.from_value(_defaults.devmode)

M.dressing_clipboard = ark.c.Observable.from_value(_defaults.dressing_clipboard)
M.dressing_dim = ark.c.Observable.from_value(_defaults.dressing_dim)
M.dressing_illuminate = ark.c.Observable.from_value(_defaults.dressing_illuminate)
M.dressing_image = ark.c.Observable.from_value(_defaults.dressing_image)
M.dressing_indent = ark.c.Observable.from_value(_defaults.dressing_indent)
M.dressing_input = ark.c.Observable.from_value(_defaults.dressing_input)
M.dressing_scroll = ark.c.Observable.from_value(_defaults.dressing_scroll)
M.dressing_select = ark.c.Observable.from_value(_defaults.dressing_select)
M.dressing_trailspace = ark.c.Observable.from_value(_defaults.dressing_trailspace)
M.dressing_ui_attach = ark.c.Observable.from_value(_defaults.dressing_ui_attach)
M.dressing_virtcolumn = ark.c.Observable.from_value(_defaults.dressing_virtcolumn)
M.dressing_winsep = ark.c.Observable.from_value(_defaults.dressing_winsep, stl.fn.falsy)

M.gitdiff_expand_all = ark.c.Observable.from_value(_defaults.gitdiff_expand_all)

return M
