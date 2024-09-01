---@type ghc.enums.context.FindScope[]
local scopes = { "W", "C", "D" }

local find_exclude_patterns = fc.c.Observable.from_value(table.concat({
  ".git/",
  ".cache/",
  ".next/",
  ".yarn/",
  "build/",
  "debug/",
  "node_modules/",
  "target/",
  "tmp/",
  "*.pdf",
  "*.mkv",
  "*.mp4",
  "*.zip",
}, ","))
local find_flag_case_sensitive = fc.c.Observable.from_value(false)
local find_flag_gitignore = fc.c.Observable.from_value(true)
local find_flag_fuzzy = fc.c.Observable.from_value(true)
local find_flag_regex = fc.c.Observable.from_value(false)
local find_file_pattern = fc.c.Observable.from_value("")
local find_scope = fc.c.Observable.from_value("C")

---@class ghc.context.session : fc.collection.Viewmodel
---@field public find_exclude_patterns  fc.types.collection.IObservable
---@field public find_flag_case_sensitive fc.types.collection.IObservable
---@field public find_flag_gitignore    fc.types.collection.IObservable
---@field public find_flag_fuzzy        fc.types.collection.IObservable
---@field public find_flag_regex        fc.types.collection.IObservable
---@field public find_file_pattern      fc.types.collection.IObservable
---@field public find_scope             fc.types.collection.IObservable
local M = require("ghc.context.session.mod")
  :register("find_exclude_patterns", find_exclude_patterns, true, true)
  :register("find_flag_case_sensitive", find_flag_case_sensitive, true, true)
  :register("find_flag_gitignore", find_flag_gitignore, true, true)
  :register("find_flag_fuzzy", find_flag_fuzzy, true, true)
  :register("find_flag_regex", find_flag_regex, true, true)
  :register("find_file_pattern", find_file_pattern, true, true)
  :register("find_scope", find_scope, true, true)

---@return ghc.enums.context.FindScope
function M.get_find_scope_carousel_next()
  local scope = find_scope:snapshot() ---@type ghc.enums.context.FindScope
  local idx = fc.array.first(scopes, scope) or 1 ---@type integer
  local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
  return scopes[idx_next]
end

---@param dirpath                       string
---@return string
function M.get_find_scope_cwd(dirpath)
  local scope = find_scope:snapshot() ---@type ghc.enums.context.FindScope

  if scope == "W" then
    return fc.path.workspace()
  end

  if scope == "C" then
    return fc.path.cwd()
  end

  if scope == "D" then
    return dirpath
  end

  fc.reporter.error({
    from = "ghc.context.session.find",
    subject = "get_find_scope_cwd",
    message = "Unknown scope.",
    details = { scope = scope, dirpath = dirpath },
  })
  return fc.path.cwd()
end

--Auto refresh statusline
vim.schedule(function()
  fml.fn.watch_observables({
    find_scope,
    find_flag_case_sensitive,
    find_flag_gitignore,
    find_flag_fuzzy,
    find_flag_regex,
  }, function()
    vim.cmd("redrawstatus")
  end)
end)
