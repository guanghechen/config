local env = require("eve.lib.env")
local functional = require("eve.lib.functional")
local md5 = require("eve.lib.md5")
local path = require("eve.lib.path")
local Frecency = require("eve.lib.collection.frecency")
local History = require("eve.lib.collection.history")
local Observable = require("eve.lib.collection.observable")

---@class eve.state.workspace : eve.t.state.workspace
local M = {}

---@return eve.t.state.workspace.data
function M.defaults()
  local is_home_config_dir = path.workspace() == env.HOME_NVIM_CONFIG ---@type boolean

  ---@type eve.t.state.data.bookmark
  local bookmark = {
    pinned = {},
  }

  ---@type eve.t.state.data.dressing
  local dressing = {
    hi_pairs = true,
    winsep_fixed = true,
    winsep_float = false,
  }

  ---@type eve.t.state.data.find
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

  ---@type eve.t.state.data.flight
  local flight = {
    autoload = false,
    autosave = true,
    copilot = is_home_config_dir,
    devmode = is_home_config_dir,
    lsp_inlay_hints = is_home_config_dir,
    lsp_code_lens = is_home_config_dir,
  }

  ---@type eve.t.state.data.frecency
  local frecency = {
    files = { items = {} },
  }

  ---@type eve.t.state.data.input_history
  local input_history = {
    find_files = { present = 0, stack = {} },
    search_in_files = { present = 0, stack = {} },
  }

  ---@type eve.t.state.data.search
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

  ---@type eve.t.state.workspace.data
  local data = {
    bookmark = bookmark,
    dressing = dressing,
    find = find,
    flight = flight,
    frecency = frecency,
    input_history = input_history,
    search = search,
  }
  return data
end

---@return eve.t.state.workspace.data
function M.dump()
  if M.state == nil then
    error("[eve.state.workspace] the state is not initialized.")
    return M.defaults()
  end

  local state = M.state ---@type eve.t.state.workspace.state

  ---@type eve.t.state.data.bookmark
  local bookmark = {
    pinned = state.bookmark.pinned:snapshot(),
  }

  ---@type eve.t.state.data.dressing
  local dressing = {
    hi_pairs = state.dressing.hi_pairs:snapshot(),
    winsep_fixed = state.dressing.winsep_fixed:snapshot(),
    winsep_float = state.dressing.winsep_float:snapshot(),
  }

  ---@type eve.t.state.data.find
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

  ---@type eve.t.state.data.flight
  local flight = {
    autoload = state.flight.autoload:snapshot(),
    autosave = state.flight.autosave:snapshot(),
    copilot = state.flight.copilot:snapshot(),
    devmode = state.flight.devmode:snapshot(),
    lsp_inlay_hints = state.flight.lsp_inlay_hints:snapshot(),
    lsp_code_lens = state.flight.lsp_code_lens:snapshot(),
  }

  ---@type eve.t.state.data.frecency
  local frecency = {
    files = state.frecency.files:dump(),
  }

  ---@type eve.t.state.data.input_history
  local input_history = {
    find_files = state.input_history.find_files:dump(),
    search_in_files = state.input_history.search_in_files:dump(),
  }

  ---@type eve.t.state.data.search
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

  ---@type eve.t.state.workspace.data
  local data = {
    bookmark = bookmark,
    dressing = dressing,
    find = find,
    flight = flight,
    frecency = frecency,
    input_history = input_history,
    search = search,
  }
  return data
end

---@param data                          eve.t.state.workspace.data
---@return nil
function M.load(data)
  if M.state == nil then
    ---@type eve.t.state.state.bookmark
    local bookmark = {
      pinned = Observable.from_value(data.bookmark.pinned),
    }

    ---@type eve.t.state.state.dressing
    local dressing = {
      hi_pairs = Observable.from_value(data.dressing.hi_pairs),
      winsep_fixed = Observable.from_value(data.dressing.winsep_fixed),
      winsep_float = Observable.from_value(data.dressing.winsep_float),
    }

    ---@type eve.t.state.state.find
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

    ---@type eve.t.state.state.flight
    local flight = {
      autoload = Observable.from_value(data.flight.autoload),
      autosave = Observable.from_value(data.flight.autosave),
      copilot = Observable.from_value(data.flight.copilot),
      devmode = Observable.from_value(data.flight.devmode),
      lsp_inlay_hints = Observable.from_value(data.flight.lsp_inlay_hints),
      lsp_code_lens = Observable.from_value(data.flight.lsp_code_lens),
    }

    ---@type eve.t.state.state.frecency
    local frecency = {
      files = Frecency.deserialize({
        data = data.frecency.files,
        normalize = function(key)
          return md5.sumhexa(key)
        end,
      }),
    }

    ---@type eve.t.state.state.input_history
    local input_history = {
      find_files = History.deserialize({
        name = "find_files",
        capacity = 100,
        data = data.input_history.find_files,
      }),
      search_in_files = History.deserialize({
        name = "search_in_files",
        capacity = 300,
        data = data.input_history.search_in_files,
      }),
    }

    ---@type eve.t.state.state.search
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

    ---@type eve.t.state.workspace.state
    local state = {
      bookmark = bookmark,
      dressing = dressing,
      find = find,
      flight = flight,
      frecency = frecency,
      input_history = input_history,
      search = search,
    }
    M.state = state
  else
    local state = M.state ---@type eve.t.state.workspace.state

    ---! bookmark
    if not functional.equals_list(state.bookmark.pinned:snapshot(), data.bookmark.pinned) then
      state.bookmark.pinned:next(data.bookmark.pinned)
    end

    ---! dressing
    state.dressing.hi_pairs:next(data.dressing.hi_pairs)
    state.dressing.winsep_fixed:next(data.dressing.winsep_fixed)
    state.dressing.winsep_float:next(data.dressing.winsep_float)

    ---! find
    state.find.flag_case_sensitive:next(data.find.flag_case_sensitive)
    state.find.flag_gitignore:next(data.find.flag_gitignore)
    state.find.flag_fuzzy:next(data.find.flag_fuzzy)
    state.find.flag_regex:next(data.find.flag_regex)
    if not functional.equals_list(state.find.includes:snapshot(), data.find.includes) then
      state.find.includes:next(data.find.includes)
    end
    if not functional.equals_list(state.find.excludes:snapshot(), data.find.excludes) then
      state.find.excludes:next(data.find.excludes)
    end
    state.find.keyword:next(data.find.keyword)
    state.find.scope:next(data.find.scope)

    ---! flight
    state.flight.autoload:next(data.flight.autoload)
    state.flight.autosave:next(data.flight.autosave)
    state.flight.copilot:next(data.flight.copilot)
    state.flight.devmode:next(data.flight.devmode)
    state.flight.lsp_inlay_hints:next(data.flight.lsp_inlay_hints)
    state.flight.lsp_code_lens:next(data.flight.lsp_code_lens)

    ---! frecency
    state.frecency.files:load(data.frecency.files)

    ---! input_history
    state.input_history.find_files:load(data.input_history.find_files)
    state.input_history.search_in_files:load(data.input_history.search_in_files)

    ---! search
    state.search.flag_case_sensitive:next(data.search.flag_case_sensitive)
    state.search.flag_gitignore:next(data.search.flag_gitignore)
    state.search.flag_regex:next(data.search.flag_regex)
    state.search.flag_replace:next(data.search.flag_replace)
    state.search.max_filesize:next(data.search.max_filesize)
    state.search.max_matches:next(data.search.max_matches)
    if not functional.equals_list(state.search.includes:snapshot(), data.search.includes) then
      state.search.includes:next(data.search.includes)
    end
    if not functional.equals_list(state.search.excludes:snapshot(), data.search.excludes) then
      state.search.excludes:next(data.search.excludes)
    end
    state.search.keyword:next(data.search.keyword)
    state.search.replacement:next(data.search.replacement)
    state.search.scope:next(data.search.scope)
    if not functional.equals_list(state.search.search_paths:snapshot(), data.search.search_paths) then
      state.search.search_paths:next(data.search.search_paths)
    end
  end
end

---@param data                          any
---@return eve.t.state.workspace.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.t.state.workspace.data

  if type(data) ~= "table" then
    return resolved
  end
  ---@cast data eve.t.state.workspace.data

  if type(data.bookmark) == "table" then
    if type(data.bookmark.pinned) == "table" then
      resolved.bookmark.pinned = data.bookmark.pinned
    end
  end

  if type(data.dressing) == "table" then
    if type(data.dressing.hi_pairs) == "boolean" then
      resolved.dressing.hi_pairs = data.dressing.hi_pairs
    end
    if type(data.dressing.winsep_fixed) == "boolean" then
      resolved.dressing.winsep_fixed = data.dressing.winsep_fixed
    end
    if type(data.dressing.winsep_float) == "boolean" then
      resolved.dressing.winsep_float = data.dressing.winsep_float
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
    if type(data.flight.lsp_inlay_hints) == "boolean" then
      resolved.flight.lsp_inlay_hints = data.flight.lsp_inlay_hints
    end
    if type(data.flight.lsp_code_lens) == "boolean" then
      resolved.flight.lsp_code_lens = data.flight.lsp_code_lens
    end
  end

  if type(data.frecency) == "table" then
    for key, frecency in pairs(data.frecency) do
      if data.frecency[key] and type(frecency) == "table" then
        if type(frecency.MAX_TIMESTAMPS) == "number" then
          data.frecency[key].MAX_TIMESTAMPS = frecency.MAX_TIMESTAMPS
        end
        if type(frecency.items) == "table" then
          data.frecency[key].items = frecency.items
        end
      end
    end
  end

  if type(data.input_history) == "table" then
    for key, history in pairs(data.input_history) do
      if data.input_history[key] and type(history) == "table" then
        if type(history.present) == "number" then
          resolved.input_history[key].present = history.present
        end
        if type(history.stack) == "table" then
          resolved.input_history[key].stack = history.stack
        end
      end
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
