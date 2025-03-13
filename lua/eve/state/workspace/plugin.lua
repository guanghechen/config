local Observable = require("eve.collection.observable")

---@class eve.state.plugin.data
---@field public render_markdown        boolean
---@field public smear_cursor           boolean
---@field public treesitter_context     boolean

---@class eve.state.plugin.state
---@field public render_markdown        eve.collection.IObservable -- boolean>
---@field public smear_cursor           eve.collection.IObservable -- boolean>
---@field public treesitter_context     eve.collection.IObservable -- boolean>

---@class eve.state.plugin
---@field public defaults               fun(): eve.state.plugin.data
---@field public dump                   fun(): eve.state.plugin.data
---@field public load                   fun(data: unknown): eve.state.plugin.state
---@field public normalize              fun(data: unknown): eve.state.plugin.data
local M = {}

local _state = nil ---@type eve.state.plugin.state | nil

---@return eve.state.plugin.data
function M.defaults()
  local is_git_repo = eve.std.path.is_repo_git() ---@type boolean

  ---@type eve.state.plugin.data
  return {
    render_markdown = true,
    smear_cursor = false, -- env.IS_WSL or env.IS_WIN,
    treesitter_context = is_git_repo,
  }
end

---@param data                        any
---@return eve.state.plugin.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.plugin.data
  if type(data) == "table" then
    if type(data.render_markdown) == "boolean" then
      resolved.render_markdown = data.render_markdown
    end
    if type(data.smear_cursor) == "boolean" then
      resolved.smear_cursor = data.smear_cursor
    end
    if type(data.treesitter_context) == "boolean" then
      resolved.treesitter_context = data.treesitter_context
    end
  end
  return resolved
end

---@return eve.state.plugin.data
function M.dump()
  if _state == nil then
    return M.defaults()
  end

  ---@type eve.state.plugin.data
  return {
    render_markdown = _state.render_markdown:snapshot(),
    smear_cursor = _state.smear_cursor:snapshot(),
    treesitter_context = _state.treesitter_context:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.plugin.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.plugin.data

  if _state == nil then
    ---@type eve.state.plugin.state
    _state = {
      render_markdown = Observable.from_value(data.render_markdown),
      smear_cursor = Observable.from_value(data.smear_cursor),
      treesitter_context = Observable.from_value(data.treesitter_context),
    }
    return _state
  end

  _state.render_markdown:next(data.render_markdown)
  _state.smear_cursor:next(data.smear_cursor)
  _state.treesitter_context:next(data.treesitter_context)
  return _state
end

return M
