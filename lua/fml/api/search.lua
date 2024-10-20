---@type t.eve.e.SearchScope[]
local scopes = { "W", "C", "D", "B" }

---@class fml.api.search
local M = {}

---@return t.eve.e.SearchScope
function M.get_scope_carousel_next()
  local scope = eve.context.state.search.scope:snapshot() ---@type t.eve.e.SearchScope
  local idx = eve.array.first(scopes, scope) or 1 ---@type integer
  local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
  return scopes[idx_next]
end

---@param dirpath                       string
---@return string
function M.get_scope_cwd(dirpath)
  local scope = eve.context.state.search.scope:snapshot() ---@type t.eve.e.SearchScope

  if scope == "W" then
    return eve.path.workspace()
  end

  if scope == "C" then
    return eve.path.cwd()
  end

  if scope == "D" then
    return dirpath
  end

  if scope == "B" then
    return dirpath
  end

  eve.reporter.error({
    from = "fml.api.search",
    subject = "get_scope_cwd",
    message = "Unknown scope.",
    details = { scope = scope, dirpath = dirpath },
  })
  return eve.path.cwd()
end

return M
