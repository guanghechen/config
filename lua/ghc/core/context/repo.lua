local Observable = require("guanghechen.observable.Observable")
local Viewmodel = require("guanghechen.viewmodel.Viewmodel")
local path = require("ghc.core.util.path")

---@class ghc.core.context.repo : guanghechen.viewmodel.Viewmodel
---@field public flag_case_sensitive guanghechen.observable.Observable
---@field public flag_enable_regex guanghechen.observable.Observable
---@field public transparency guanghechen.observable.Observable
---@field public searching_keyword guanghechen.observable.Observable
--
local context = Viewmodel.new({
  name = "repo",
  filepath = path.gen_session_related_filepath({ filename = "repo.json" }),
})
  :register("flag_case_sensitive", Observable.new(false), true)
  :register("flag_enable_regex", Observable.new(false), true)
  :register("searching_keyword", Observable.new(""), true)
  :register("transparency", Observable.new(false), true)

context:load()

return context
