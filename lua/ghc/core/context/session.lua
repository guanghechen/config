local Observable = require("guanghechen.observable.Observable")
local Viewmodel = require("guanghechen.viewmodel.Viewmodel")
local util_observable = require("guanghechen.util.observable")
local util_path = require("guanghechen.util.path")

---@class ghc.core.context.session : guanghechen.viewmodel.Viewmodel
---@field public buftype_extra guanghechen.observable.Observable
---@field public caller_winnr guanghechen.observable.Observable
---@field public caller_bufnr guanghechen.observable.Observable
---@field public filemap_dirty guanghechen.observable.Observable
---@field public find_file_enable_case_sensitive guanghechen.observable.Observable
---@field public find_file_enable_regex guanghechen.observable.Observable
---@field public find_file_last_command guanghechen.observable.Observable
---@field public find_file_keyword guanghechen.observable.Observable
---@field public find_file_scope guanghechen.observable.Observable
---@field public find_recent_keyword guanghechen.observable.Observable
---@field public find_recent_scope guanghechen.observable.Observable
---@field public replace_enable_case_sensitive guanghechen.observable.Observable
---@field public replace_replace_keyword guanghechen.observable.Observable
---@field public replace_search_keyword guanghechen.observable.Observable
---@field public replace_path guanghechen.observable.Observable
---@field public search_last_command guanghechen.observable.Observable
---@field public search_enable_case_sensitive guanghechen.observable.Observable
---@field public search_enable_regex guanghechen.observable.Observable
---@field public search_scope guanghechen.observable.Observable
---@field public search_keyword guanghechen.observable.Observable
local context = Viewmodel.new({
  name = "config",
  filepath = util_path.locate_session_filepath({ filename = "config.json" }),
})
  :register("buftype_extra", Observable.new(nil), false)
  :register("caller_winnr", Observable.new(nil), false)
  :register("caller_bufnr", Observable.new(nil), false)
  :register("filemap_dirty", Observable.new(true), true)
  :register("find_file_enable_case_sensitive", Observable.new(false), true)
  :register("find_file_enable_regex", Observable.new(false), true)
  :register("find_file_scope", Observable.new("C"), true)
  :register("find_file_last_command", Observable.new(nil), false)
  :register("find_file_keyword", Observable.new(""), true)
  :register("find_recent_keyword", Observable.new(""), true)
  :register("find_recent_scope", Observable.new("C"), true)
  :register("replace_enable_case_sensitive", Observable.new(false), true)
  :register("replace_replace_keyword", Observable.new(""), true)
  :register("replace_search_keyword", Observable.new(""), true)
  :register("replace_path", Observable.new(""), true)
  :register("search_last_command", Observable.new(nil), false)
  :register("search_enable_case_sensitive", Observable.new(false), true)
  :register("search_enable_regex", Observable.new(false), true)
  :register("search_scope", Observable.new("C"), true)
  :register("search_keyword", Observable.new(""), true)

context:load()

--Auto refresh statusline
util_observable.watch_observables({
  context.buftype_extra,
  context.find_file_enable_case_sensitive,
  context.find_file_enable_regex,
  context.find_file_scope,
  context.find_recent_scope,
  context.search_enable_case_sensitive,
  context.search_enable_regex,
  context.search_scope,
}, function()
  vim.cmd("redrawstatus")
end)

return context
