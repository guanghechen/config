local Observable = fml.collection.Observable

---@param paths                         string
---@return string
local function normalize_paths(paths)
  return fml.oxi.normalize_comma_list(paths) ---@type string
end

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
---@field public replace_pattern            fml.types.collection.IObservable
---@field public search_cwd                 fml.types.collection.IObservable
---@field public search_exclude_patterns    fml.types.collection.IObservable
---@field public search_flag_case_sensitive fml.types.collection.IObservable
---@field public search_flag_regex          fml.types.collection.IObservable
---@field public search_include_patterns    fml.types.collection.IObservable
---@field public search_mode                fml.types.collection.IObservable
---@field public search_paths               fml.types.collection.IObservable
---@field public search_pattern             fml.types.collection.IObservable
---@field public search_scope               fml.types.collection.IObservable
local M = require("ghc.context.session.mod")
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

--Auto refresh statusline
vim.schedule(function()
  fml.fn.watch_observables({
    search_flag_case_sensitive,
    search_flag_regex,
    search_scope,
  }, function()
    vim.schedule(function()
      vim.cmd("redrawstatus")
    end)
  end)
end)
