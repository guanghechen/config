local guanghechen = require("guanghechen")
local Observable = require("guanghechen.observable.Observable")
local Viewmodel = require("guanghechen.viewmodel.Viewmodel")

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
---@field public flight_copilot guanghechen.observable.Observable
---@field public replace_enable_case_sensitive guanghechen.observable.Observable
---@field public replace_keyword guanghechen.observable.Observable
---@field public replace_path guanghechen.observable.Observable
---@field public search_last_command guanghechen.observable.Observable
---@field public search_enable_case_sensitive guanghechen.observable.Observable
---@field public search_enable_regex guanghechen.observable.Observable
---@field public search_include_paths guanghechen.observable.Observable
---@field public search_keyword guanghechen.observable.Observable
---@field public search_scope guanghechen.observable.Observable
local context = Viewmodel.new({
  name = "context:session",
  filepath = guanghechen.util.path.locate_session_filepath({ filename = "config.json" }),
})
  :register("buftype_extra", Observable.new(nil), false, false)
  :register("caller_winnr", Observable.new(nil), false, false)
  :register("caller_bufnr", Observable.new(nil), false, false)
  :register("filemap_dirty", Observable.new(true), true, false)
  :register("find_file_enable_case_sensitive", Observable.new(false), true, false)
  :register("find_file_enable_regex", Observable.new(false), true, false)
  :register("find_file_scope", Observable.new("C"), true, false)
  :register("find_file_last_command", Observable.new(nil), false, false)
  :register("find_file_keyword", Observable.new(""), true, false)
  :register("find_recent_keyword", Observable.new(""), true, false)
  :register("find_recent_scope", Observable.new("C"), true, false)
  :register("flight_copilot", Observable.new(false), true, false)
  :register("replace_enable_case_sensitive", Observable.new(false), true, false)
  :register("replace_keyword", Observable.new(""), true, false)
  :register("replace_path", Observable.new(""), true, false)
  :register("search_last_command", Observable.new(nil), false, false)
  :register("search_enable_case_sensitive", Observable.new(false), true, false)
  :register("search_enable_regex", Observable.new(false), true, false)
  :register("search_include_paths", Observable.new({ "" }), true, false)
  :register("search_keyword", Observable.new(""), true, false)
  :register("search_scope", Observable.new("C"), true, false)

context:load()
context:auto_reload()

--Auto refresh statusline
guanghechen.util.observable.watch_observables({
  context.buftype_extra,
  context.find_file_enable_case_sensitive,
  context.find_file_enable_regex,
  context.find_file_scope,
  context.find_recent_scope,
  context.flight_copilot,
  context.search_enable_case_sensitive,
  context.search_enable_regex,
  context.search_scope,
}, function()
  vim.cmd("redrawstatus")
end)

return context
