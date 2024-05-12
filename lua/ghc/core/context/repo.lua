local Observable = require("guanghechen.observable.Observable")
local Viewmodel = require("guanghechen.viewmodel.Viewmodel")
local path = require("ghc.core.util.path")
local util_observable = require("guanghechen.util.observable")

---@class ghc.core.context.repo : guanghechen.viewmodel.Viewmodel
---@field public search_last_command guanghechen.observable.Observable
---@field public search_enable_case_sensitive guanghechen.observable.Observable
---@field public search_enable_regex guanghechen.observable.Observable
---@field public search_scope guanghechen.observable.Observable
---@field public searching guanghechen.observable.Observable
---@field public search_keyword guanghechen.observable.Observable
---@field public transparency guanghechen.observable.Observable
--
local context = Viewmodel.new({
  name = "repo",
  filepath = path.gen_session_related_filepath({ filename = "repo.json" }),
})
  :register("search_last_command", Observable.new(nil), false)
  :register("search_enable_case_sensitive", Observable.new(false), true)
  :register("search_enable_regex", Observable.new(false), true)
  :register("search_scope", Observable.new("C"), true)
  :register("searching", Observable.new(false), false)
  :register("search_keyword", Observable.new(""), true)
  :register("transparency", Observable.new(false), true)

context:load()

--Auto refresh statusline
util_observable.watch_observables({
  context.search_enable_case_sensitive,
  context.search_enable_regex,
  context.search_scope,
  context.searching,
  context.transparency,
}, function()
  vim.cmd("redrawstatus")
end)

return context
