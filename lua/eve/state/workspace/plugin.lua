---@class eve.state.plugin.data
---@field public render_markdown        boolean
---@field public smear_cursor           boolean
---@field public treesitter_context     boolean

---@class eve.state.plugin.state
---@field public render_markdown        eve.collection.IObservable -- boolean>
---@field public smear_cursor           eve.collection.IObservable -- boolean>
---@field public treesitter_context     eve.collection.IObservable -- boolean>

---@class eve.state.plugin : eve.state.plugin.state
---@field public defaults               fun(): eve.state.plugin.data
---@field public dump                   fun(): eve.state.plugin.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.plugin.data
local M = {}

---@return eve.state.plugin.data
function M.defaults()
  local is_git_repo = eve.path.is_repo_git() ---@type boolean

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
  ---@type eve.state.plugin.data
  return {
    render_markdown = M.render_markdown:snapshot(),
    smear_cursor = M.smear_cursor:snapshot(),
    treesitter_context = M.treesitter_context:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.plugin.data

  M.render_markdown:next(data.render_markdown)
  M.smear_cursor:next(data.smear_cursor)
  M.treesitter_context:next(data.treesitter_context)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.state.plugin.data
M.render_markdown = eve.col.Observable.from_value(_defaults.render_markdown)
M.smear_cursor = eve.col.Observable.from_value(_defaults.smear_cursor)
M.treesitter_context = eve.col.Observable.from_value(_defaults.treesitter_context)

return M
