local Observable = fml.collection.Observable

---@type ghc.enums.context.FindScope[]
local scopes = { "W", "C", "D" }

local find_exclude_patterns = Observable.from_value(table.concat({
  ".cache/**",
  ".git/**",
  ".yarn/**",
  "**/build/**",
  "**/debug/**",
  "**/node_modules/**",
  "**/target/**",
  "**/tmp/**",
  "**/*.pdf",
  "**/*.mkv",
  "**/*.mp4",
  "**/*.zip",
}, ","))
local find_file_pattern = Observable.from_value("")
local find_scope = Observable.from_value("C")

---@class ghc.context.session : fml.collection.Viewmodel
---@field public find_exclude_patterns       fml.types.collection.IObservable
---@field public find_file_pattern          fml.types.collection.IObservable
---@field public find_scope                 fml.types.collection.IObservable
local M = require("ghc.context.session.mod")
  :register("find_exclude_patterns", find_exclude_patterns, true, true)
  :register("find_file_pattern", find_file_pattern, true, true)
  :register("find_scope", find_scope, true, true)

---@return ghc.enums.context.FindScope
function M.get_find_scope_carousel_next()
  local scope = find_scope:snapshot() ---@type ghc.enums.context.FindScope
  local idx = fml.array.first(scopes, scope) or 1 ---@type integer
  local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
  return scopes[idx_next]
end

---@param dirpath                       string
---@return string
function M.get_find_scope_cwd(dirpath)
  local scope = find_scope:snapshot() ---@type ghc.enums.context.FindScope

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
    from = "ghc.context.session.find",
    subject = "get_find_scope_cwd",
    message = "Unknown scope.",
    details = { scope = scope, dirpath = dirpath },
  })
  return fml.path.cwd()
end

--Auto refresh statusline
vim.schedule(function()
  fml.fn.watch_observables({ find_scope }, function()
    vim.schedule(function()
      vim.cmd("redrawstatus")
    end)
  end)
end)
