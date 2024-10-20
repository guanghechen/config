---@type t.eve.e.FindScope[]
local scopes = { "W", "C", "D" }

---@class fml.api.find
local M = {}

---@return t.eve.e.FindScope
function M.get_scope_carousel_next()
  local scope = eve.context.state.find.scope:snapshot() ---@type t.eve.e.FindScope
  local idx = eve.array.first(scopes, scope) or 1 ---@type integer
  local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
  return scopes[idx_next]
end

---@param dirpath                       string
---@return string
function M.get_scope_cwd(dirpath)
  local scope = eve.context.state.find.scope:snapshot() ---@type t.eve.e.FindScope

  if scope == "W" then
    return eve.path.workspace()
  end

  if scope == "C" then
    return eve.path.cwd()
  end

  if scope == "D" then
    return dirpath
  end

  eve.reporter.error({
    from = "fml.api.find",
    subject = "get_scope_cwd",
    message = "Unknown scope.",
    details = { scope = scope, dirpath = dirpath },
  })
  return eve.path.cwd()
end

return M
