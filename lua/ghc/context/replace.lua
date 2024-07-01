local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

---@param paths                         string
---@return string
local function normalize_paths(paths)
  return fml.oxi.normalize_comma_list(paths) ---@type string
end

local cwd = Observable.from_value(fml.path.cwd())
local mode = Observable.from_value("search")
local flag_regex = Observable.from_value(true)
local flag_case_sensitive = Observable.from_value(true)
local search_pattern = Observable.from_value("")
local replace_pattern = Observable.from_value("")
local search_paths = Observable.new({ initial_value = "", normalize = normalize_paths })
local include_patterns = Observable.new({ initial_value = "", normalize = normalize_paths })
local exclude_patterns = Observable.new({ initial_value = ".git/", normalize = normalize_paths })

---@class ghc.context.replace : fml.collection.Viewmodel
---@field public cwd                    fml.types.collection.IObservable
---@field public mode                   fml.types.collection.IObservable
---@field public flag_regex             fml.types.collection.IObservable
---@field public flag_case_sensitive    fml.types.collection.IObservable
---@field public search_pattern         fml.types.collection.IObservable
---@field public replace_pattern        fml.types.collection.IObservable
---@field public search_paths           fml.types.collection.IObservable
---@field public include_patterns       fml.types.collection.IObservable
---@field public exclude_patterns       fml.types.collection.IObservable
local context = Viewmodel.new({
      name = "context:session:replace",
      filepath = fml.path.locate_session_filepath({ filename = "replace.json" }),
    })
    :register("cwd", cwd, true, true)
    :register("mode", mode, true, true)
    :register("flag_regex", flag_regex, true, true)
    :register("flag_case_sensitive", flag_case_sensitive, true, true)
    :register("search_pattern", search_pattern, true, true)
    :register("replace_pattern", replace_pattern, true, true)
    :register("search_paths", search_paths, true, true)
    :register("include_patterns", include_patterns, true, true)
    :register("exclude_patterns", exclude_patterns, true, true)

context:load()
--context:auto_reload()

--Auto refresh statusline
fml.fn.watch_observables({
  context.flag_regex,
  context.flag_case_sensitive,
}, function()
  vim.cmd("redrawstatus")
end)

return context
