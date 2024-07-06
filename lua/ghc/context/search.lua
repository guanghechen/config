local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

local context_filepath = fml.path.locate_session_filepath({ filename = "search.json" })

---@param paths                         string
---@return string
local function normalize_paths(paths)
  return fml.oxi.normalize_comma_list(paths) ---@type string
end

local cwd = Observable.from_value(fml.path.cwd())
local exclude_patterns = Observable.new({ initial_value = ".git/", normalize = normalize_paths })
local find_file_pattern = Observable.from_value("")
local find_scope = Observable.from_value("C")
local flag_case_sensitive = Observable.from_value(true)
local flag_regex = Observable.from_value(true)
local flight_copilot = Observable.from_value(false)
local include_patterns = Observable.new({ initial_value = "", normalize = normalize_paths })
local mode = Observable.from_value("search")
local replace_pattern = Observable.from_value("")
local search_paths = Observable.new({ initial_value = "", normalize = normalize_paths })
local search_pattern = Observable.from_value("")
local search_scope = Observable.from_value("C")

---@class ghc.context.search : fml.collection.Viewmodel
---@field public cwd                    fml.types.collection.IObservable
---@field public exclude_patterns       fml.types.collection.IObservable
---@field public find_file_pattern      fml.types.collection.IObservable
---@field public find_scope             fml.types.collection.IObservable
---@field public flag_case_sensitive    fml.types.collection.IObservable
---@field public flag_regex             fml.types.collection.IObservable
---@field public flight_copilot         fml.types.collection.IObservable
---@field public include_patterns       fml.types.collection.IObservable
---@field public mode                   fml.types.collection.IObservable
---@field public replace_pattern        fml.types.collection.IObservable
---@field public search_paths           fml.types.collection.IObservable
---@field public search_pattern         fml.types.collection.IObservable
---@field public search_scope           fml.types.collection.IObservable
local context = Viewmodel
    .new({ name = "context:session:search", filepath = context_filepath })
    :register("cwd", cwd, true, true)
    :register("exclude_patterns", exclude_patterns, true, true)
    :register("find_file_pattern", find_file_pattern, true, true)
    :register("find_scope", find_scope, true, true)
    :register("flag_regex", flag_regex, true, true)
    :register("flag_case_sensitive", flag_case_sensitive, true, true)
    :register("flight_copilot", flight_copilot, true, true)
    :register("include_patterns", include_patterns, true, true)
    :register("mode", mode, true, true)
    :register("replace_pattern", replace_pattern, true, true)
    :register("search_paths", search_paths, true, true)
    :register("search_pattern", search_pattern, true, true)
    :register("search_scope", search_scope, true, true)

if not fml.path.is_exist(context_filepath) then
  context:save()
end

context:load()
--context:auto_reload()

--Auto refresh statusline
fml.fn.watch_observables({
  context.find_scope,
  context.flag_case_sensitive,
  context.flag_regex,
  context.flight_copilot,
  context.search_scope,
}, function()
  vim.schedule(function()
    vim.cmd("redrawstatus")
  end)
end)

return context
