local Observable = fml.collection.Observable
local Viewmodel = fml.collection.Viewmodel

local context_filepath = fml.path.locate_session_filepath({ filename = "replace.json" })

---@alias ghc.context.replace.IMode
---| "replace"
---| "search"

---@alias ghc.context.replace.IDataKey
---|"cwd"
---|"mode"
---|"flag_regex"
---|"flag_case_sensitive"
---|"search_pattern"
---|"replace_pattern"
---|"search_paths"
---|"include_patterns"
---|"exclude_patterns"

---@type ghc.types.context.replace.IData
local data = {
  cwd = fml.path.cwd(),
  mode = "search",
  flag_regex = true,
  flag_case_sensitive = true,
  search_pattern = "",
  replace_pattern = "",
  search_paths = "",
  include_patterns = "",
  exclude_patterns = ".git/",
}

---@class ghc.context.replace : fml.collection.Viewmodel
---@field public cwd                  fml.types.collection.IObservable
---@field public mode                 fml.types.collection.IObservable
---@field public flag_regex           fml.types.collection.IObservable
---@field public flag_case_sensitive  fml.types.collection.IObservable
---@field public search_pattern       fml.types.collection.IObservable
---@field public replace_pattern      fml.types.collection.IObservable
---@field public search_paths         fml.types.collection.IObservable
---@field public include_patterns     fml.types.collection.IObservable
---@field public exclude_patterns     fml.types.collection.IObservable
local context = Viewmodel.new({
  name = "context:session:replace",
  filepath = context_filepath,
})
  :register("cwd", Observable.from_value(fml.path.cwd()), true, true)
  :register("mode", Observable.from_value("search"), true, true)
  :register("flag_regex", Observable.from_value(true), true, true)
  :register("flag_case_sensitive", Observable.from_value(true), true, true)
  :register("search_pattern", Observable.from_value(""), true, true)
  :register("replace_pattern", Observable.from_value(""), true, true)
  :register("search_paths", Observable.from_value(""), true, true)
  :register("include_patterns", Observable.from_value(""), true, true)
  :register("exclude_patterns", Observable.from_value(".git/"), true, true)

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
