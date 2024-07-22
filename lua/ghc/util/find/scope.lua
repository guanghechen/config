---@class ghc.util.find.scope
local M = {}

---@type ghc.enums.context.FindScope[]
M.scopes = { "W", "C", "D" }

---@type table<ghc.enums.context.FindScope, string>
M.scope_2_name = {
  W = "workspace",
  C = "cwd",
  D = "directory",
}

---@param scope                         ghc.enums.context.FindScope
---@return ghc.enums.context.FindScope
function M.toggle_carousel(scope)
  local idx = fml.array.first(M.scopes, scope) or 1 ---@type integer
  local idx_next = idx == #M.scopes and 1 or idx + 1 ---@type integer
  return M.scopes[idx_next]
end

---@param scope                         ghc.enums.context.FindScope
---@param dirpath                       string
---@return string
function M.get_cwd(scope, dirpath)
  if scope == "W" then
    return fml.path.workspace()
  end

  if scope == "C" then
    return fml.path.cwd()
  end

  if scope == "D" then
    return dirpath
  end

  fml.reporter.error({
    from = "ghc.util.find.scope",
    subject = "get_cwd",
    message = "Unknown scope.",
    details = { scope = scope, dirpath = dirpath },
  })
  return dirpath
end

return M
