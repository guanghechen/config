---@class eve.state.plugin.data
---@field public render_markdown        boolean
---@field public treesitter_context     boolean

---@class eve.state.plugin.state
---@field public render_markdown        eve.std.collection.IObservable
---@field public treesitter_context     eve.std.collection.IObservable

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
    treesitter_context = M.treesitter_context:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.plugin.data

  M.render_markdown:next(data.render_markdown)
  M.treesitter_context:next(data.treesitter_context)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.state.plugin.data
M.render_markdown = eve.std.Observable.from_value(_defaults.render_markdown)
M.treesitter_context = eve.std.Observable.from_value(_defaults.treesitter_context)

return M
