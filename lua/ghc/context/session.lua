local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

---@type string|nil
local context_filepath = fml.path.is_git_repo() and fml.path.locate_session_filepath({ filename = "session.json" })
  or nil

---@param paths                         string
---@return string
local function normalize_paths(paths)
  return fml.oxi.normalize_comma_list(paths) ---@type string
end

local find_file_pattern = Observable.from_value("")
local find_scope = Observable.from_value("C")
local flight_autoload_session = Observable.from_value(false)
local flight_copilot = Observable.from_value(false)
local replace_pattern = Observable.from_value("")
local search_cwd = Observable.from_value(fml.path.cwd())
local search_exclude_patterns = Observable.new({ initial_value = ".git/", normalize = normalize_paths })
local search_flag_case_sensitive = Observable.from_value(true)
local search_flag_regex = Observable.from_value(true)
local search_include_patterns = Observable.new({ initial_value = "", normalize = normalize_paths })
local search_mode = Observable.from_value("search")
local search_paths = Observable.new({ initial_value = "", normalize = normalize_paths })
local search_pattern = Observable.from_value("")
local search_scope = Observable.from_value("C")

---@class ghc.context.session : fml.collection.Viewmodel
---@field public find_file_pattern          fml.types.collection.IObservable
---@field public find_scope                 fml.types.collection.IObservable
---@field public flight_autoload_session    fml.types.collection.IObservable
---@field public flight_copilot             fml.types.collection.IObservable
---@field public replace_pattern            fml.types.collection.IObservable
---@field public search_cwd                 fml.types.collection.IObservable
---@field public search_exclude_patterns    fml.types.collection.IObservable
---@field public search_flag_case_sensitive fml.types.collection.IObservable
---@field public search_flag_regex          fml.types.collection.IObservable
---@field public search_include_patterns           fml.types.collection.IObservable
---@field public search_mode                fml.types.collection.IObservable
---@field public search_paths               fml.types.collection.IObservable
---@field public search_pattern             fml.types.collection.IObservable
---@field public search_scope               fml.types.collection.IObservable
local context = Viewmodel.new({ name = "context:session", filepath = context_filepath })
  :register("find_file_pattern", find_file_pattern, true, true)
  :register("find_scope", find_scope, true, true)
  :register("flight_autoload_session", flight_autoload_session, true, true)
  :register("flight_copilot", flight_copilot, true, true)
  :register("replace_pattern", replace_pattern, true, true)
  :register("search_cwd", search_cwd, true, true)
  :register("search_exclude_patterns", search_exclude_patterns, true, true)
  :register("search_flag_case_sensitive", search_flag_case_sensitive, true, true)
  :register("search_flag_regex", search_flag_regex, true, true)
  :register("search_include_patterns", search_include_patterns, true, true)
  :register("search_mode", search_mode, true, true)
  :register("search_paths", search_paths, true, true)
  :register("search_pattern", search_pattern, true, true)
  :register("search_scope", search_scope, true, true)

if context_filepath ~= nil and fml.path.is_exist(context_filepath) then
  context:load()
end

--Auto refresh statusline
fml.fn.watch_observables({
  context.find_scope,
  context.search_flag_case_sensitive,
  context.search_flag_regex,
  context.flight_copilot,
  context.search_scope,
}, function()
  vim.schedule(function()
    vim.cmd("redrawstatus")
  end)
end)

return context
