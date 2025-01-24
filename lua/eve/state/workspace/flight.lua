local env = require("eve.builtin.env")
local path = require("eve.builtin.path")
local Observable = require("eve.collection.observable")
local setting = require("eve.constant.setting")

---@class eve.state.flight.data
---@field public ai                     boolean
---@field public ai_provider            eve.e.AiProvider
---@field public autoload               boolean
---@field public autosave               boolean
---@field public devmode                boolean
---
---@field public dressing_hipairs       boolean
---@field public dressing_input         boolean
---@field public dressing_select        boolean
---@field public dressing_winsep_fixed  boolean
---@field public dressing_winsep_float  boolean
---
---@field public lsp_inlay_hints        boolean
---@field public lsp_code_lens          boolean
---
---@field public smear_cursor           boolean
---@field public spellcheck             boolean
---@field public treesitter_context     boolean

---@class eve.state.flight.state
---@field public ai                     eve.collection.IObservable
---@field public ai_provider            eve.collection.IObservable
---@field public autoload               eve.collection.IObservable
---@field public autosave               eve.collection.IObservable
---@field public devmode                eve.collection.IObservable
---
---@field public dressing_hipairs       eve.collection.IObservable
---@field public dressing_input         eve.collection.IObservable
---@field public dressing_select        eve.collection.IObservable
---@field public dressing_winsep_fixed  eve.collection.IObservable
---@field public dressing_winsep_float  eve.collection.IObservable
---
---@field public lsp_inlay_hints        eve.collection.IObservable
---@field public lsp_code_lens          eve.collection.IObservable
---
---@field public smear_cursor           eve.collection.IObservable
---@field public spellcheck             eve.collection.IObservable
---@field public treesitter_context     eve.collection.IObservable

---@class eve.state.flight
---@field public defaults               fun(): eve.state.flight.data
---@field public dump                   fun(): eve.state.flight.data
---@field public load                   fun(data: unknown): eve.state.flight.state
---@field public normalize              fun(data: unknown): eve.state.flight.data
local M = {}

local _state = nil ---@type eve.state.flight.state | nil

---@class eve.state.flight.reposcope_map
local reposcope_map = {
  [".config"] = {
    "alacritty",
    "btop",
    "fd",
    "fish",
    "fzf",
    "ghostty",
    "guanghechen",
    "helix",
    "kitty",
    "lazygit",
    "lsd",
    "nvim",
    "nvim-nvchad",
    "pwsh",
    "ripgrep",
    "tmux",
    "wezterm",
    "yazi",
    "zellij",
  },
  ["guanghechen"] = {
    "algorithm.ts",
    "asset",
    "koa",
    "mirror",
    "node-scaffolds",
    "react-kit",
    "sora",
    "static-resources",
  },
  ["yozora"] = {
    "yozora",
    "yozora-react",
    "yozora-html",
    "gatsby-scaffolds",
  },
}

---@return eve.state.flight.data
function M.defaults()
  local workspace = path.workspace() ---@type string
  local is_home_config_dir = workspace == env.HOME_NVIM_CONFIG ---@type boolean
  local is_git_repo = path.is_git_repo() ---@type boolean

  local is_sourcecode = false ---@type boolean
  local is_playground = false ---@type boolean
  if is_git_repo then
    local pieces = path.split(workspace) ---@type string[]
    is_sourcecode = vim.list_contains(pieces, "sourcecode") or vim.list_contains(pieces, "sourcecodes") ---@type boolean
    is_playground = vim.list_contains(pieces, "playground") ---@type boolean

    if not is_sourcecode and #pieces > 2 then
      local reposcope = pieces[#pieces - 1] ---@type string
      local reponame = pieces[#pieces] ---@type string
      local reponames = reposcope_map[reposcope] ---@type string[]|nil
      is_sourcecode = reponames ~= nil and vim.list_contains(reponames, reponame) or reposcope == "lazy" ---@type boolean
    end
  end

  ---@type eve.state.flight.data
  return {
    ai = is_home_config_dir or is_sourcecode or is_playground,
    ai_provider = "copilot",
    autoload = false,
    autosave = is_git_repo,
    devmode = is_home_config_dir,

    dressing_hipairs = true,
    dressing_input = true,
    dressing_select = true,
    dressing_winsep_fixed = true,
    dressing_winsep_float = false,

    lsp_inlay_hints = is_git_repo,
    lsp_code_lens = is_git_repo,

    smear_cursor = env.IS_WSL or env.IS_WIN,
    spellcheck = is_git_repo and not (is_sourcecode or is_playground),
    treesitter_context = is_git_repo,
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

    if type(data.lsp_inlay_hints) == "boolean" then
      resolved.lsp_inlay_hints = data.lsp_inlay_hints
    end
    if type(data.lsp_code_lens) == "boolean" then
      resolved.lsp_code_lens = data.lsp_code_lens
    end

    if type(data.smear_cursor) == "boolean" then
      resolved.smear_cursor = data.smear_cursor
    end
    if type(data.spellcheck) == "boolean" then
      resolved.spellcheck = data.spellcheck
    end
    if type(data.treesitter_context) == "boolean" then
      resolved.treesitter_context = data.treesitter_context
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
    autoload = _state.autoload:snapshot(),
    autosave = _state.autosave:snapshot(),
    devmode = _state.devmode:snapshot(),

    dressing_hipairs = _state.dressing_hipairs:snapshot(),
    dressing_input = _state.dressing_input:snapshot(),
    dressing_select = _state.dressing_select:snapshot(),
    dressing_winsep_fixed = _state.dressing_winsep_fixed:snapshot(),
    dressing_winsep_float = _state.dressing_winsep_float:snapshot(),

    lsp_inlay_hints = _state.lsp_inlay_hints:snapshot(),
    lsp_code_lens = _state.lsp_code_lens:snapshot(),

    smear_cursor = _state.smear_cursor:snapshot(),
    spellcheck = _state.spellcheck:snapshot(),
    treesitter_context = _state.treesitter_context:snapshot(),
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
      autoload = Observable.from_value(data.autoload),
      autosave = Observable.from_value(data.autosave),
      devmode = Observable.from_value(data.devmode),

      dressing_hipairs = Observable.from_value(data.dressing_hipairs),
      dressing_input = Observable.from_value(data.dressing_input),
      dressing_select = Observable.from_value(data.dressing_select),
      dressing_winsep_fixed = Observable.from_value(data.dressing_winsep_fixed),
      dressing_winsep_float = Observable.from_value(data.dressing_winsep_float),

      lsp_inlay_hints = Observable.from_value(data.lsp_inlay_hints),
      lsp_code_lens = Observable.from_value(data.lsp_code_lens),

      smear_cursor = Observable.from_value(data.smear_cursor),
      spellcheck = Observable.from_value(data.spellcheck),
      treesitter_context = Observable.from_value(data.treesitter_context),
    }
    return _state
  end

  _state.ai:next(data.ai)
  _state.ai_provider:next(data.ai_provider)
  _state.autoload:next(data.autoload)
  _state.autosave:next(data.autosave)
  _state.devmode:next(data.devmode)

  _state.dressing_hipairs:next(data.dressing_hipairs)
  _state.dressing_input:next(data.dressing_input)
  _state.dressing_select:next(data.dressing_select)
  _state.dressing_winsep_fixed:next(data.dressing_winsep_fixed)
  _state.dressing_winsep_float:next(data.dressing_winsep_float)

  _state.lsp_inlay_hints:next(data.lsp_inlay_hints)
  _state.lsp_code_lens:next(data.lsp_code_lens)

  _state.smear_cursor:next(data.smear_cursor)
  _state.spellcheck:next(data.spellcheck)
  _state.treesitter_context:next(data.treesitter_context)
  return _state
end

return M
