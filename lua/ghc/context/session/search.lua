---@type ghc.enums.context.SearchScope[]
local scopes = { "W", "C", "D", "B" }

---@param paths                         string
---@return string
local function normalize_paths(paths)
  return eve.oxi.normalize_comma_list(paths) ---@type string
end

local search_exclude_patterns = eve.c.Observable.new({
  initial_value = table.concat({
    ".git/**",
    "**/.cache/**",
    "**/.next/**",
    "**/.yarn/**",
    "**/node_modules/**",
    "*.jar",
    "*.pdf",
    "*.mkv",
    "*.mp4",
    "*.zip",
  }, ","),
  normalize = normalize_paths,
})
local search_flag_case_sensitive = eve.c.Observable.from_value(true)
local search_flag_gitignore = eve.c.Observable.from_value(true)
local search_flag_regex = eve.c.Observable.from_value(true)
local search_flag_replace = eve.c.Observable.from_value(false)
local search_include_patterns = eve.c.Observable.new({ initial_value = "", normalize = normalize_paths })
local search_max_matches = eve.c.Observable.from_value(500)
local search_max_filesize = eve.c.Observable.from_value("1M")
local search_paths = eve.c.Observable.new({ initial_value = "", normalize = normalize_paths })
local search_pattern = eve.c.Observable.from_value("")
local search_replace_pattern = eve.c.Observable.from_value("")
local search_scope = eve.c.Observable.from_value("C")

---@class ghc.context.session : eve.collection.Viewmodel
---@field public search_exclude_patterns    eve.types.collection.IObservable
---@field public search_flag_case_sensitive eve.types.collection.IObservable
---@field public search_flag_gitignore      eve.types.collection.IObservable
---@field public search_flag_regex          eve.types.collection.IObservable
---@field public search_flag_replace        eve.types.collection.IObservable
---@field public search_include_patterns    eve.types.collection.IObservable
---@field public search_max_filesize        eve.types.collection.IObservable
---@field public search_max_matches         eve.types.collection.IObservable
---@field public search_paths               eve.types.collection.IObservable
---@field public search_pattern             eve.types.collection.IObservable
---@field public search_replace_pattern     eve.types.collection.IObservable
---@field public search_scope               eve.types.collection.IObservable
local M = require("ghc.context.session.mod")
  :register("search_exclude_patterns", search_exclude_patterns, true, true)
  :register("search_flag_case_sensitive", search_flag_case_sensitive, true, true)
  :register("search_flag_gitignore", search_flag_gitignore, true, true)
  :register("search_flag_regex", search_flag_regex, true, true)
  :register("search_flag_replace", search_flag_replace, true, true)
  :register("search_include_patterns", search_include_patterns, true, true)
  :register("search_max_filesize", search_max_filesize, true, true)
  :register("search_max_matches", search_max_matches, true, true)
  :register("search_paths", search_paths, true, true)
  :register("search_pattern", search_pattern, true, true)
  :register("search_replace_pattern", search_replace_pattern, true, true)
  :register("search_scope", search_scope, true, true)

---@return ghc.enums.context.SearchScope
function M.get_search_scope_carousel_next()
  local scope = search_scope:snapshot() ---@type ghc.enums.context.SearchScope
  local idx = eve.array.first(scopes, scope) or 1 ---@type integer
  local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
  return scopes[idx_next]
end

---@param dirpath                       string
---@return string
function M.get_search_scope_cwd(dirpath)
  local scope = search_scope:snapshot() ---@type ghc.enums.context.SearchScope

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
    from = "ghc.context.session.search",
    subject = "get_search_scope_cwd",
    message = "Unknown scope.",
    details = { scope = scope, dirpath = dirpath },
  })
  return eve.path.cwd()
end

--Auto refresh statusline
vim.schedule(function()
  fml.fn.watch_observables({
    search_flag_case_sensitive,
    search_flag_gitignore,
    search_flag_regex,
    search_scope,
  }, function()
    vim.cmd("redrawstatus")
  end)
end)
