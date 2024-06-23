local Observable = fml.collection.Observable
local Viewmodel = require("guanghechen.viewmodel.Viewmodel")

---@class ghc.core.context.session : guanghechen.viewmodel.Viewmodel
---@field public buftype_extra fml.types.collection.IObservable
---@field public caller_winnr fml.types.collection.IObservable
---@field public caller_bufnr fml.types.collection.IObservable
---@field public filemap_dirty fml.types.collection.IObservable
---@field public find_file_enable_case_sensitive fml.types.collection.IObservable
---@field public find_file_enable_regex fml.types.collection.IObservable
---@field public find_file_last_command fml.types.collection.IObservable
---@field public find_file_keyword fml.types.collection.IObservable
---@field public find_file_scope fml.types.collection.IObservable
---@field public find_recent_keyword fml.types.collection.IObservable
---@field public find_recent_scope fml.types.collection.IObservable
---@field public flight_copilot fml.types.collection.IObservable
---@field public replace_enable_case_sensitive fml.types.collection.IObservable
---@field public replace_keyword fml.types.collection.IObservable
---@field public replace_path fml.types.collection.IObservable
---@field public search_last_command fml.types.collection.IObservable
---@field public search_enable_case_sensitive fml.types.collection.IObservable
---@field public search_enable_regex fml.types.collection.IObservable
---@field public search_include_paths fml.types.collection.IObservable
---@field public search_keyword fml.types.collection.IObservable
---@field public search_scope fml.types.collection.IObservable
local context = Viewmodel.new({
  name = "context:session",
  filepath = fml.path.locate_session_filepath({ filename = "config.json" }),
})
  :register("buftype_extra", Observable.from_value(nil), false, false)
  :register("caller_winnr", Observable.from_value(nil), false, false)
  :register("caller_bufnr", Observable.from_value(nil), false, false)
  :register("filemap_dirty", Observable.from_value(true), true, false)
  :register("find_file_enable_case_sensitive", Observable.from_value(false), true, false)
  :register("find_file_enable_regex", Observable.from_value(false), true, false)
  :register("find_file_scope", Observable.from_value("C"), true, false)
  :register("find_file_last_command", Observable.from_value(nil), false, false)
  :register("find_file_keyword", Observable.from_value(""), true, false)
  :register("find_recent_keyword", Observable.from_value(""), true, false)
  :register("find_recent_scope", Observable.from_value("C"), true, false)
  :register("flight_copilot", Observable.from_value(false), true, false)
  :register("replace_enable_case_sensitive", Observable.from_value(false), true, false)
  :register("replace_keyword", Observable.from_value(""), true, false)
  :register("replace_path", Observable.from_value(""), true, false)
  :register("search_last_command", Observable.from_value(nil), false, false)
  :register("search_enable_case_sensitive", Observable.from_value(false), true, false)
  :register("search_enable_regex", Observable.from_value(false), true, false)
  :register("search_include_paths", Observable.from_value({ "" }), true, false)
  :register("search_keyword", Observable.from_value(""), true, false)
  :register("search_scope", Observable.from_value("C"), true, false)

context:load()
context:auto_reload()

--Auto refresh statusline
fml.fn.watch_observables({
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
