local session = require("ghc.context.session")

local __searching = false ---@type boolean
---@diagnostic disable-next-line: unused-local
local __replace_dirty = true ---@type boolean
local __search_dirty = true ---@type boolean
local __search_result = nil ---@type fml.std.oxi.search.IResult|nil
local __search_dirty_ticker = fml.collection.Observable.from_value(0)
local __replace_dirty_ticker = fml.collection.Observable.from_value(0)

---@alias ghc.command.replace.state.IKey
---| "cwd"
---| "mode"
---| "flag_regex"
---| "flag_case_sensitive"
---| "search_pattern"
---| "replace_pattern"
---| "search_paths"
---| "include_patterns"
---| "exclude_patterns"

---@class ghc.command.replace.state.IData
---@field public cwd                    string
---@field public mode                   ghc.enums.command.replace.Mode
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public search_paths           string
---@field public include_patterns       string
---@field public exclude_patterns       string

---@class ghc.command.replace.state
local M = {}

fml.fn.watch_observables({
  session.search_cwd,
  session.search_flag_regex,
  session.search_flag_case_sensitive,
  session.search_pattern,
  session.search_paths,
  session.search_include_patterns,
  session.search_exclude_patterns,
}, function()
  __search_dirty = true
  __search_dirty_ticker:next(__search_dirty_ticker:get_snapshot() + 1)
end)

fml.fn.watch_observables({
  session.search_mode,
  session.replace_pattern,
}, function()
  ---@diagnostic disable-next-line: unused-local
  __replace_dirty = true
  __replace_dirty_ticker:next(__replace_dirty_ticker:get_snapshot() + 1)
end)

---@return string
function M.get_cwd()
  return session.search_cwd:get_snapshot()
end

---@param cwd                           string|nil
---@return nil
function M.set_cwd(cwd)
  if type(cwd) == "string" then
    session.search_cwd:next(cwd)
  end
end

---@return ghc.enums.command.replace.Mode
function M.get_mode()
  return session.search_mode:get_snapshot()
end

---@param mode                          ghc.enums.command.replace.Mode|nil
---@return nil
function M.set_mode(mode)
  if type(mode) == "string" then
    session.search_mode:next(mode)
  end
end

---@return nil
function M.tog_mode()
  local cur = session.search_mode:get_snapshot() ---@type ghc.enums.command.replace.Mode
  local nxt = cur == "replace" and "search" or "replace"
  session.search_mode:next(nxt)
end

---@return boolean
function M.get_flag_regex()
  return session.search_flag_regex:get_snapshot()
end

---@param flag                          boolean|nil
---@return nil
function M.set_flag_regex(flag)
  if type(flag) == "boolean" then
    session.search_flag_regex:next(flag)
  end
end

function M.tog_flag_regex()
  local flag = session.search_flag_regex:get_snapshot() ---@type boolean
  session.search_flag_regex:next(not flag)
end

---@return boolean
function M.get_flag_case_sensitive()
  return session.search_flag_case_sensitive:get_snapshot()
end

---@param flag                          boolean|nil
---@return nil
function M.set_flag_case_sensitive(flag)
  if type(flag) == "boolean" then
    session.search_flag_case_sensitive:next(flag)
  end
end

function M.tog_flag_case_sensitive()
  local flag = session.search_flag_case_sensitive:get_snapshot() ---@type boolean
  session.search_flag_case_sensitive:next(not flag)
end

---@return string
function M.get_search_pattern()
  return session.search_pattern:get_snapshot()
end

---@param pattern                       string|nil
---@return nil
function M.set_search_pattern(pattern)
  if type(pattern) == "string" then
    session.search_pattern:next(pattern)
  end
end

---@return string
function M.get_replace_pattern()
  return session.replace_pattern:get_snapshot()
end

---@param pattern                       string|nil
---@return nil
function M.set_replace_pattern(pattern)
  if type(pattern) == "string" then
    session.replace_pattern:next(pattern)
  end
end

---@return string
function M.get_search_paths()
  return session.search_paths:get_snapshot()
end

---@param paths                         string|nil
---@return nil
function M.set_search_paths(paths)
  if type(paths) == "string" then
    session.search_paths:next(paths)
  end
end

---@return string
function M.get_include_patterns()
  return session.search_include_patterns:get_snapshot()
end

---@param patterns                      string|nil
---@return nil
function M.set_include_patterns(patterns)
  if type(patterns) == "string" then
    session.search_include_patterns:next(patterns)
  end
end
---@return string
function M.get_exclude_patterns()
  return session.search_exclude_patterns:get_snapshot()
end

---@param patterns                      string|nil
---@return nil
function M.set_exclude_patterns(patterns)
  if type(patterns) == "string" then
    session.search_exclude_patterns:next(patterns)
  end
end

---@param key                           ghc.command.replace.state.IKey
---@return boolean|string|ghc.enums.command.replace.Mode|nil
function M.get_value(key)
  local method_identifier = "get_" .. key
  local method = M[method_identifier]
  return type(method) == "function" and method() or nil
end

---@param key                           ghc.command.replace.state.IKey
---@param val                           boolean|string|ghc.enums.command.replace.Mode
---@return nil
function M.set_value(key, val)
  local method_identifier = "set_" .. key
  local method = M[method_identifier]
  return type(method) == "function" and method(val) or nil
end

---@return ghc.command.replace.state.IData
function M.get_data()
  ---@type ghc.command.replace.state.IData
  local data = {
    cwd = M.get_cwd(),
    mode = M.get_mode(),
    flag_regex = M.get_flag_regex(),
    flag_case_sensitive = M.get_flag_case_sensitive(),
    search_pattern = M.get_search_pattern(),
    replace_pattern = M.get_replace_pattern(),
    search_paths = M.get_search_paths(),
    include_patterns = M.get_include_patterns(),
    exclude_patterns = M.get_exclude_patterns(),
  }
  return data
end

---@param data                          ghc.command.replace.state.IData
---@return nil
function M.set_data(data)
  M.set_cwd(data.cwd)
  M.set_mode(data.mode)
  M.set_flag_regex(data.flag_regex)
  M.set_flag_case_sensitive(data.flag_case_sensitive)
  M.set_search_pattern(data.search_pattern)
  M.set_replace_pattern(data.replace_pattern)
  M.set_search_paths(data.search_paths)
  M.set_include_patterns(data.include_patterns)
  M.set_exclude_patterns(data.exclude_patterns)
end

---@param on_change                     fun(): nil
---@return fml.types.collection.IUnsubscribable
function M.watch_search_changes(on_change)
  ---@type  fml.types.collection.ISubscriber
  local subscriber = fml.collection.Subscriber.new({
    on_next = on_change,
  })
  return __search_dirty_ticker:subscribe(subscriber)
end

---@param on_change                     fun(): nil
---@return fml.types.collection.IUnsubscribable
function M.watch_replace_changes(on_change)
  ---@type  fml.types.collection.ISubscriber
  local subscriber = fml.collection.Subscriber.new({
    on_next = on_change,
  })
  return __replace_dirty_ticker:subscribe(subscriber)
end

---@param force                         ?boolean
---@return fml.std.oxi.search.IResult
function M.search(force)
  if force or __search_dirty then
    if __searching then
      __search_dirty = true
    else
      __searching = true
      fml.fn.run_async(function()
        ---@type fml.std.oxi.search.IParams
        local options = {
          cwd = M.get_cwd(),
          flag_case_sensitive = M.get_flag_case_sensitive(),
          flag_regex = M.get_flag_regex(),
          search_pattern = M.get_search_pattern(),
          search_paths = M.get_search_paths(),
          include_patterns = M.get_include_patterns(),
          exclude_patterns = M.get_exclude_patterns(),
        }

        __search_dirty = false
        local ok, result = pcall(fml.oxi.search, options)
        if ok then
          __search_result = result
          __search_dirty_ticker:next(__search_dirty_ticker:get_snapshot() + 1)
        else
          fml.reporter.error({
            from = "ghc.command.replace.state",
            subject = "search",
            message = "Failed to search",
            details = { options = options },
          })
        end

        M.search(false)
        __searching = false
      end)
    end
  end

  ---@cast __search_result  fml.std.oxi.search.IResult
  return __search_result
end

return M
