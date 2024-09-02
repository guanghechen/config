---@type ghc.enums.context.FindScope[]
local scopes = { "W", "C", "D" }

local find_exclude_patterns = eve.c.Observable.from_value(table.concat({
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
local find_flag_case_sensitive = eve.c.Observable.from_value(false)
local find_flag_gitignore = eve.c.Observable.from_value(true)
local find_flag_fuzzy = eve.c.Observable.from_value(true)
local find_flag_regex = eve.c.Observable.from_value(false)
local find_file_pattern = eve.c.Observable.from_value("")
local find_scope = eve.c.Observable.from_value("C")

---@class ghc.context.session : eve.collection.Viewmodel
---@field public find_exclude_patterns  eve.types.collection.IObservable
---@field public find_flag_case_sensitive eve.types.collection.IObservable
---@field public find_flag_gitignore    eve.types.collection.IObservable
---@field public find_flag_fuzzy        eve.types.collection.IObservable
---@field public find_flag_regex        eve.types.collection.IObservable
---@field public find_file_pattern      eve.types.collection.IObservable
---@field public find_scope             eve.types.collection.IObservable
local M = require("ghc.context.session.mod")
  :register("find_exclude_patterns", find_exclude_patterns, true, false)
  :register("find_flag_case_sensitive", find_flag_case_sensitive, true, false)
  :register("find_flag_gitignore", find_flag_gitignore, true, false)
  :register("find_flag_fuzzy", find_flag_fuzzy, true, false)
  :register("find_flag_regex", find_flag_regex, true, false)
  :register("find_file_pattern", find_file_pattern, true, false)
  :register("find_scope", find_scope, true, false)

---@return ghc.enums.context.FindScope
function M.get_find_scope_carousel_next()
  local scope = find_scope:snapshot() ---@type ghc.enums.context.FindScope
  local idx = eve.array.first(scopes, scope) or 1 ---@type integer
  local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
  return scopes[idx_next]
end

---@param dirpath                       string
---@return string
function M.get_find_scope_cwd(dirpath)
  local scope = find_scope:snapshot() ---@type ghc.enums.context.FindScope

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
    from = "ghc.context.session.find",
    subject = "get_find_scope_cwd",
    message = "Unknown scope.",
    details = { scope = scope, dirpath = dirpath },
  })
  return eve.path.cwd()
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
