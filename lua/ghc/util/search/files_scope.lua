---@class ghc.util.search.files_scope
local M = {}

---@type ghc.enums.context.SearchScope[]
M.scopes = { "W", "C", "D", "B" }

---@type table<ghc.enums.context.SearchScope, string>
M.scope_2_name = {
  W = "workspace",
  C = "cwd",
  D = "directory",
  B = "buffer",
}

---@param scope                         ghc.enums.context.SearchScope
---@return ghc.enums.context.SearchScope
function M.get_carousel_next(scope)
  local idx = fml.array.first(M.scopes, scope) or 1 ---@type integer
  local idx_next = idx == #M.scopes and 1 or idx + 1 ---@type integer
  return M.scopes[idx_next]
end

---@param scope                         ghc.enums.context.FindScope
---@param dirpath                       string
---@param bufpath                       string|nil
---@return string
function M.get_cwd(scope, dirpath, bufpath)
  if scope == "W" then
    return fml.path.workspace()
  end

  if scope == "C" then
    return fml.path.cwd()
  end

  if scope == "D" then
    return dirpath
  end

  if scope == "B" then
    return bufpath or dirpath
  end

  fml.reporter.error({
    from = "ghc.util.search.files_scope",
    subject = "get_cwd",
    message = "Unknown scope.",
    details = { scope = scope, dirpath = dirpath, bufpath = bufpath },
  })
  return fml.path.cwd()
end

return M
