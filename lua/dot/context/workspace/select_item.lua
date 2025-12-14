---@class dot.context.select.item.data
---@field public flag_case_sensitive    boolean
---@field public flag_exclude           boolean
---@field public flag_foldempty         boolean
---@field public flag_fuzzy             boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public flag_selected          boolean
---@field public flag_textonly          boolean
---@field public flag_viewtype          string
---@field public includes               string[]
---@field public excludes               string[]
---@field public search_pattern         string
---@field public search_pattern_history ark.c.history.ISerializedData

---@class dot.context.select.item.state
---@field public flag_case_sensitive    ark.c.Observable
---@field public flag_exclude           ark.c.Observable
---@field public flag_foldempty         ark.c.Observable
---@field public flag_fuzzy             ark.c.Observable
---@field public flag_gitignore         ark.c.Observable
---@field public flag_regex             ark.c.Observable
---@field public flag_selected          ark.c.Observable
---@field public flag_textonly          ark.c.Observable
---@field public flag_viewtype          ark.c.Observable
---@field public includes               ark.c.Observable
---@field public excludes               ark.c.Observable
---@field public search_pattern         ark.c.Observable
---@field public search_pattern_history ark.c.History

---@class dot.context.select.item
---@field public defaults               fun(): dot.context.select.item.data
---@field public normalize              fun(data: unknown): dot.context.select.item.data
---@field public dump                   fun(state: dot.context.select.item.state): dot.context.select.item.data
---@field public load                   fun(state: dot.context.select.item.state|nil, name: string, data: unknown): dot.context.select.item.state
local M = {}

---@return dot.context.select.item.data
function M.defaults()
  ---@type dot.context.select.item.data
  return {
    flag_case_sensitive = false,
    flag_exclude = true,
    flag_fuzzy = false,
    flag_gitignore = true,
    flag_regex = false,
    flag_selected = false,
    flag_foldempty = true,
    flag_viewtype = "tree",
    flag_textonly = false,
    includes = {},
    excludes = {
      ".git/",
      ".cache/",
      ".next/",
      ".yarn/",
      "build/",
      "debug/",
      "node_modules/",
      "target/",
      "tmp/",
      "*.pdf",
      "*.mkv",
      "*.mp4",
      "*.zip",
    },
    search_pattern = "",
    search_pattern_history = { present = 0, stack = {} },
  }
end

---@param data                          any
---@return dot.context.select.item.data
function M.normalize(data)
  local resolved = M.defaults() ---@type dot.context.select.item.data
  if type(data) == "table" then
    if type(data.flag_case_sensitive) == "boolean" then
      resolved.flag_case_sensitive = data.flag_case_sensitive
    end
    if type(data.flag_exclude) == "boolean" then
      resolved.flag_exclude = data.flag_exclude
    end
    if type(data.flag_fuzzy) == "boolean" then
      resolved.flag_fuzzy = data.flag_fuzzy
    end
    if type(data.flag_gitignore) == "boolean" then
      resolved.flag_gitignore = data.flag_gitignore
    end
    if type(data.flag_regex) == "boolean" then
      resolved.flag_regex = data.flag_regex
    end
    if type(data.flag_selected) == "boolean" then
      resolved.flag_selected = data.flag_selected
    end
    if type(data.flag_foldempty) == "boolean" then
      resolved.flag_foldempty = data.flag_foldempty
    end
    if type(data.flag_textonly) == "boolean" then
      resolved.flag_textonly = data.flag_textonly
    end
    if type(data.flag_viewtype) == "string" then
      if data.flag_viewtype == "tree" or data.flag_viewtype == "list" then
        resolved.flag_viewtype = data.flag_viewtype
      end
    end
    if type(data.includes) == "table" then
      resolved.includes = data.includes
    end
    if type(data.excludes) == "table" then
      resolved.excludes = data.excludes
    end
    if type(data.search_pattern) == "string" then
      resolved.search_pattern = data.search_pattern
    end
    if type(data.search_pattern_history) == "table" then
      if type(data.search_pattern_history.present) == "number" then
        resolved.search_pattern_history.present = data.search_pattern_history.present
      end
      if type(data.search_pattern_history.stack) == "table" then
        resolved.search_pattern_history.stack = data.search_pattern_history.stack
      end
    end
  end

  ---@type dot.context.select.item.data
  return resolved
end

---@param state                         dot.context.select.item.state
---@return dot.context.select.item.data
function M.dump(state)
  ---@type dot.context.select.item.data
  return {
    flag_case_sensitive = state.flag_case_sensitive:snapshot(),
    flag_exclude = state.flag_exclude:snapshot(),
    flag_foldempty = state.flag_foldempty:snapshot(),
    flag_fuzzy = state.flag_fuzzy:snapshot(),
    flag_gitignore = state.flag_gitignore:snapshot(),
    flag_regex = state.flag_regex:snapshot(),
    flag_selected = state.flag_selected:snapshot(),
    flag_textonly = state.flag_textonly:snapshot(),
    flag_viewtype = state.flag_viewtype:snapshot(),
    includes = state.includes:snapshot(),
    excludes = state.excludes:snapshot(),
    search_pattern = state.search_pattern:snapshot(),
    search_pattern_history = state.search_pattern_history:dump(),
  }
end

---@param state                         dot.context.select.item.state|nil
---@param name                          string
---@param raw_data                      any
---@return dot.context.select.item.state
function M.load(state, name, raw_data)
  local data = M.normalize(raw_data) ---@type dot.context.select.item.data

  if state == nil then
    ---@type dot.context.select.item.state
    state = {
      flag_case_sensitive = ark.c.Observable.from_value(data.flag_case_sensitive),
      flag_exclude = ark.c.Observable.from_value(data.flag_exclude),
      flag_foldempty = ark.c.Observable.from_value(data.flag_foldempty),
      flag_fuzzy = ark.c.Observable.from_value(data.flag_fuzzy),
      flag_gitignore = ark.c.Observable.from_value(data.flag_gitignore),
      flag_regex = ark.c.Observable.from_value(data.flag_regex),
      flag_selected = ark.c.Observable.from_value(data.flag_selected),
      flag_textonly = ark.c.Observable.from_value(data.flag_textonly),
      flag_viewtype = ark.c.Observable.from_value(data.flag_viewtype),
      includes = ark.c.Observable.from_value(data.includes),
      excludes = ark.c.Observable.from_value(data.excludes),
      search_pattern = ark.c.Observable.from_value(data.search_pattern),
      search_pattern_history = ark.c.History.deserialize({
        name = name,
        capacity = 100,
        data = data.search_pattern_history,
      }),
    }
    return state
  end

  state.flag_case_sensitive:next(data.flag_case_sensitive)
  state.flag_exclude:next(data.flag_exclude)
  state.flag_foldempty:next(data.flag_foldempty)
  state.flag_fuzzy:next(data.flag_fuzzy)
  state.flag_gitignore:next(data.flag_gitignore)
  state.flag_regex:next(data.flag_regex)
  state.flag_selected:next(data.flag_selected)
  state.flag_textonly:next(data.flag_textonly)
  state.flag_viewtype:next(data.flag_viewtype)
  if not ark.fn.equals_list(state.includes:snapshot(), data.includes) then
    state.includes:next(data.includes)
  end
  if not ark.fn.equals_list(state.excludes:snapshot(), data.excludes) then
    state.excludes:next(data.excludes)
  end
  state.search_pattern:next(data.search_pattern)
  state.search_pattern_history:load(data.search_pattern_history)
  return state
end

return M
