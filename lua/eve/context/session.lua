local Observable = require("eve.collection.observable")
local std_array = require("eve.std.array")

---@class eve.context.session : t.eve.context.session
local M = {}

---@return t.eve.context.session.data
function M.defaults()
  ---@type t.eve.context.data.bookmark
  local bookmark = {
    pinned = {},
  }

  ---@type t.eve.context.data.find
  local find = {
    flag_case_sensitive = false,
    flag_gitignore = true,
    flag_fuzzy = false,
    flag_regex = false,
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
    keyword = "",
    scope = "C",
  }

  ---@type t.eve.context.data.flight
  local flight = {
    autoload = false,
    autosave = true,
    copilot = false,
    devmode = false,
  }

  ---@type t.eve.context.data.search
  local search = {
    flag_case_sensitive = true,
    flag_gitignore = true,
    flag_regex = false,
    flag_replace = false,
    max_filesize = "1M",
    max_matches = 500,
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
    keyword = "",
    replacement = "",
    scope = "C",
    search_paths = {},
  }

  ---@type t.eve.context.session.data
  local data = {
    bookmark = bookmark,
    find = find,
    flight = flight,
    search = search,
  }
  return data
end

---@return t.eve.context.session.data
function M.dump()
  if M.state == nil then
    error("[eve.context.session] the state is not initialized.")
    return M.defaults()
  end

  local state = M.state ---@type t.eve.context.session.state

  ---@type t.eve.context.data.bookmark
  local bookmark = {
    pinned = state.bookmark.pinned:snapshot(),
  }

  ---@type t.eve.context.data.find
  local find = {
    flag_case_sensitive = state.find.flag_case_sensitive:snapshot(),
    flag_gitignore = state.find.flag_gitignore:snapshot(),
    flag_fuzzy = state.find.flag_fuzzy:snapshot(),
    flag_regex = state.find.flag_regex:snapshot(),
    includes = state.find.includes:snapshot(),
    excludes = state.find.excludes:snapshot(),
    keyword = state.find.keyword:snapshot(),
    scope = state.find.scope:snapshot(),
  }

  ---@type t.eve.context.data.flight
  local flight = {
    autoload = state.flight.autoload:snapshot(),
    autosave = state.flight.autosave:snapshot(),
    copilot = state.flight.copilot:snapshot(),
    devmode = state.flight.devmode:snapshot(),
  }

  ---@type t.eve.context.data.search
  local search = {
    flag_case_sensitive = state.search.flag_case_sensitive:snapshot(),
    flag_gitignore = state.search.flag_gitignore:snapshot(),
    flag_regex = state.search.flag_regex:snapshot(),
    flag_replace = state.search.flag_replace:snapshot(),
    max_matches = state.search.max_matches:snapshot(),
    max_filesize = state.search.max_filesize:snapshot(),
    includes = state.search.includes:snapshot(),
    excludes = state.search.excludes:snapshot(),
    keyword = state.search.keyword:snapshot(),
    replacement = state.search.replacement:snapshot(),
    scope = state.search.scope:snapshot(),
    search_paths = state.search.search_paths:snapshot(),
  }

  ---@type t.eve.context.session.data
  local data = {
    bookmark = bookmark,
    find = find,
    flight = flight,
    search = search,
  }
  return data
end

---@param data                          t.eve.context.session.data
---@return nil
function M.load(data)
  if M.state == nil then
    ---@type t.eve.context.state.bookmark
    local bookmark = {
      pinned = Observable.from_value(data.bookmark.pinned),
    }

    ---@type t.eve.context.state.find
    local find = {
      flag_case_sensitive = Observable.from_value(data.find.flag_case_sensitive),
      flag_gitignore = Observable.from_value(data.find.flag_gitignore),
      flag_fuzzy = Observable.from_value(data.find.flag_fuzzy),
      flag_regex = Observable.from_value(data.find.flag_regex),
      includes = Observable.from_value(data.find.includes),
      excludes = Observable.from_value(data.find.excludes),
      keyword = Observable.from_value(data.find.keyword),
      scope = Observable.from_value(data.find.scope),
    }

    ---@type t.eve.context.state.flight
    local flight = {
      autoload = Observable.from_value(data.flight.autoload),
      autosave = Observable.from_value(data.flight.autosave),
      copilot = Observable.from_value(data.flight.copilot),
      devmode = Observable.from_value(data.flight.devmode),
    }

    ---@type t.eve.context.state.search
    local search = {
      flag_case_sensitive = Observable.from_value(data.search.flag_case_sensitive),
      flag_gitignore = Observable.from_value(data.search.flag_gitignore),
      flag_regex = Observable.from_value(data.search.flag_regex),
      flag_replace = Observable.from_value(data.search.flag_replace),
      max_filesize = Observable.from_value(data.search.max_filesize),
      max_matches = Observable.from_value(data.search.max_matches),
      includes = Observable.from_value(data.search.includes),
      excludes = Observable.from_value(data.search.excludes),
      keyword = Observable.from_value(data.search.keyword),
      replacement = Observable.from_value(data.search.replacement),
      scope = Observable.from_value(data.search.scope),
      search_paths = Observable.from_value(data.search.search_paths),
    }

    ---@type t.eve.context.session.state
    local state = {
      bookmark = bookmark,
      find = find,
      flight = flight,
      search = search,
    }
    M.state = state
  else
    local state = M.state ---@type t.eve.context.session.state

    ---! bookmark
    if not std_array.equals(state.bookmark.pinned:snapshot(), data.bookmark.pinned) then
      state.bookmark.pinned:next(data.bookmark.pinned)
    end

    ---! find
    state.find.flag_case_sensitive:next(data.find.flag_case_sensitive)
    state.find.flag_gitignore:next(data.find.flag_gitignore)
    state.find.flag_fuzzy:next(data.find.flag_fuzzy)
    state.find.flag_regex:next(data.find.flag_regex)
    if not std_array.equals(state.find.includes:snapshot(), data.find.includes) then
      state.find.includes:next(data.find.includes)
    end
    if not std_array.equals(state.find.excludes:snapshot(), data.find.excludes) then
      state.find.excludes:next(data.find.excludes)
    end
    state.find.keyword:next(data.find.keyword)
    state.find.scope:next(data.find.scope)

    ---! flight
    state.flight.autoload:next(data.flight.autoload)
    state.flight.autosave:next(data.flight.autosave)
    state.flight.copilot:next(data.flight.copilot)
    state.flight.devmode:next(data.flight.devmode)

    ---! search
    state.search.flag_case_sensitive:next(data.search.flag_case_sensitive)
    state.search.flag_gitignore:next(data.search.flag_gitignore)
    state.search.flag_regex:next(data.search.flag_regex)
    state.search.flag_replace:next(data.search.flag_replace)
    state.search.max_filesize:next(data.search.max_filesize)
    state.search.max_matches:next(data.search.max_matches)
    if not std_array.equals(state.search.includes:snapshot(), data.search.includes) then
      state.search.includes:next(data.search.includes)
    end
    if not std_array.equals(state.search.excludes:snapshot(), data.search.excludes) then
      state.search.excludes:next(data.search.excludes)
    end
    state.search.keyword:next(data.search.keyword)
    state.search.replacement:next(data.search.replacement)
    state.search.scope:next(data.search.scope)
    if not std_array.equals(state.search.search_paths:snapshot(), data.search.search_paths) then
      state.search.search_paths:next(data.search.search_paths)
    end
  end
end

---@param data                          any
---@return t.eve.context.session.data
function M.normalize(data)
  local resolved = M.defaults() ---@type t.eve.context.session.data

  if type(data) ~= "table" then
    return resolved
  end
  ---@cast data t.eve.context.session.data

  if type(data.bookmark) == "table" then
    if type(data.bookmark.pinned) == "table" then
      resolved.bookmark.pinned = data.bookmark.pinned
    end
  end

  if type(data.find) == "table" then
    if type(data.find.flag_case_sensitive) == "boolean" then
      resolved.find.flag_case_sensitive = data.find.flag_case_sensitive
    end
    if type(data.find.flag_gitignore) == "boolean" then
      resolved.find.flag_gitignore = data.find.flag_gitignore
    end
    if type(data.find.flag_fuzzy) == "boolean" then
      resolved.find.flag_fuzzy = data.find.flag_fuzzy
    end
    if type(data.find.flag_regex) == "boolean" then
      resolved.find.flag_regex = data.find.flag_regex
    end
    if type(data.find.includes) == "table" then
      resolved.find.includes = data.find.includes
    end
    if type(data.find.excludes) == "table" then
      resolved.find.excludes = data.find.excludes
    end
    if type(data.find.keyword) == "string" then
      resolved.find.keyword = data.find.keyword
    end
    if type(data.find.scope) == "string" then
      resolved.find.scope = data.find.scope
    end
  end

  if type(data.flight) == "table" then
    if type(data.flight.autoload) == "boolean" then
      resolved.flight.autoload = data.flight.autoload
    end
    if type(data.flight.autosave) == "boolean" then
      resolved.flight.autosave = data.flight.autosave
    end
    if type(data.flight.copilot) == "boolean" then
      resolved.flight.copilot = data.flight.copilot
    end
    if type(data.flight.devmode) == "boolean" then
      resolved.flight.devmode = data.flight.devmode
    end
  end

  if type(data.search) == "table" then
    if type(data.search.flag_case_sensitive) == "boolean" then
      resolved.search.flag_case_sensitive = data.search.flag_case_sensitive
    end
    if type(data.search.flag_gitignore) == "boolean" then
      resolved.search.flag_gitignore = data.search.flag_gitignore
    end
    if type(data.search.flag_regex) == "boolean" then
      resolved.search.flag_regex = data.search.flag_regex
    end
    if type(data.search.flag_replace) == "boolean" then
      resolved.search.flag_replace = data.search.flag_replace
    end
    if type(data.search.max_filesize) == "string" then
      resolved.search.max_filesize = data.search.max_filesize
    end
    if type(data.search.max_matches) == "number" then
      resolved.search.max_matches = data.search.max_matches
    end
    if type(data.search.includes) == "table" then
      resolved.search.includes = data.search.includes
    end
    if type(data.search.excludes) == "table" then
      resolved.search.excludes = data.search.excludes
    end
    if type(data.search.keyword) == "string" then
      resolved.search.keyword = data.search.keyword
    end
    if type(data.search.replacement) == "string" then
      resolved.search.replacement = data.search.replacement
    end
    if type(data.search.scope) == "string" then
      resolved.search.scope = data.search.scope
    end
    if type(data.search.search_paths) == "table" then
      resolved.search.search_paths = data.search.search_paths
    end
  end

  return resolved
end

return M
