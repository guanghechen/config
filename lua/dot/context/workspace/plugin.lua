---@class dot.context.plugin.data
---@field public render_markdown        boolean
---@field public treesitter_context     boolean

---@class dot.context.plugin.state
---@field public render_markdown        stl.c.Observable
---@field public treesitter_context     stl.c.Observable

---@class dot.context.plugin : dot.context.plugin.state
---@field public defaults               fun(): dot.context.plugin.data
---@field public dump                   fun(): dot.context.plugin.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): dot.context.plugin.data
local M = {}

---@return dot.context.plugin.data
function M.defaults()
  local is_git_repo = dot.path.is_git_repo() ---@type boolean

  ---@type dot.context.plugin.data
  return {
    render_markdown = false,
    treesitter_context = is_git_repo,
  }
end

---@param data                          any
---@return dot.context.plugin.data
function M.normalize(data)
  local resolved = M.defaults() ---@type dot.context.plugin.data
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

---@return dot.context.plugin.data
function M.dump()
  ---@type dot.context.plugin.data
  return {
    render_markdown = M.render_markdown:snapshot(),
    treesitter_context = M.treesitter_context:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type dot.context.plugin.data

  M.render_markdown:next(data.render_markdown)
  M.treesitter_context:next(data.treesitter_context)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type dot.context.plugin.data
M.render_markdown = stl.c.Observable.from_value(_defaults.render_markdown)
M.treesitter_context = stl.c.Observable.from_value(_defaults.treesitter_context)

return M
