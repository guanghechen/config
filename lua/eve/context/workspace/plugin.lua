---@class eve.context.plugin.data
---@field public mini_trailspace        boolean
---@field public render_markdown        boolean
---@field public treesitter_context     boolean

---@class eve.context.plugin.state
---@field public mini_trailspace        std.collection.IObservable
---@field public render_markdown        std.collection.IObservable
---@field public treesitter_context     std.collection.IObservable

---@class eve.context.plugin : eve.context.plugin.state
---@field public defaults               fun(): eve.context.plugin.data
---@field public dump                   fun(): eve.context.plugin.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.plugin.data
local M = {}

---@return eve.context.plugin.data
function M.defaults()
  local is_git_repo = std.path.is_git_repo() ---@type boolean

  ---@type eve.context.plugin.data
  return {
    mini_trailspace = true,
    render_markdown = false,
    treesitter_context = is_git_repo,
  }
end

---@param data                        any
---@return eve.context.plugin.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.plugin.data
  if type(data) == "table" then
    if type(data.mini_trailspace) == "boolean" then
      resolved.mini_trailspace = data.mini_trailspace
    end
    if type(data.render_markdown) == "boolean" then
      resolved.render_markdown = data.render_markdown
    end
    if type(data.treesitter_context) == "boolean" then
      resolved.treesitter_context = data.treesitter_context
    end
  end
  return resolved
end

---@return eve.context.plugin.data
function M.dump()
  ---@type eve.context.plugin.data
  return {
    mini_trailspace = M.mini_trailspace:snapshot(),
    render_markdown = M.render_markdown:snapshot(),
    treesitter_context = M.treesitter_context:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.plugin.data

  M.mini_trailspace:next(data.mini_trailspace)
  M.render_markdown:next(data.render_markdown)
  M.treesitter_context:next(data.treesitter_context)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.plugin.data
M.mini_trailspace = std.Observable.from_value(_defaults.mini_trailspace)
M.render_markdown = std.Observable.from_value(_defaults.render_markdown)
M.treesitter_context = std.Observable.from_value(_defaults.treesitter_context)

return M
