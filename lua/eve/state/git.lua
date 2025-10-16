local __module_name__ = "eve.state.git" ---@type string

local DEFAULT_GIT_STATUS_HL = "f_ft_git_other" ---@type string
local REFRESH_INTERVAL_MS = 5 * 60 * 1000 ---@type integer
local REFRESH_DEBOUNCE_MS = 200 ---@type integer
local FS_WATCH_DEBOUNCE_MS = 3000 ---@type integer

---@type table<string, string>
local GIT_STATUS_HIGHLIGHT = {
  A = "f_ft_git_add",
  M = "f_ft_git_change",
  D = "f_ft_git_delete",
  R = "f_ft_git_rename",
  C = "f_ft_git_rename",
  T = "f_ft_git_change",
  U = "f_ft_git_unmerged",
  ["?"] = "f_ft_git_untracked",
  ["!"] = "f_ft_git_ignored",
}

---@class eve.state.git
local M = {}

---@class eve.state.git.cache
---@field initialized                 boolean
---@field workspace                   string|nil
---@field last_refresh                integer
---@field status_table                table<string, std.git.StatusEntry>
---@field status_groups               table<string, table<string, boolean>>
---@field file_status                 table<string, string>
---@field file_display                table<string, string>
---@field file_summary                table<string, string|nil>
---@field file_stage                  table<string, "staged"|"unstaged"|"mixed"|nil>
---@field dir_display                 table<string, string>
---@field dir_summary                 table<string, string|nil>
---@field dir_stage                   table<string, "staged"|"unstaged"|"mixed"|nil>
---@field dir_codes                   table<string, table<string, boolean>>
local cache = {
  initialized = false,
  workspace = nil,
  last_refresh = 0,
  status_table = {},
  status_groups = {},
  file_status = {},
  file_display = {},
  file_summary = {},
  file_stage = {},
  dir_display = {},
  dir_summary = {},
  dir_stage = {},
  dir_codes = {},
}

---@class eve.state.git.watchers
---@field workspace                   string|nil
---@field fs                           fun()[]
---@field interval                    uv.uv_timer_t|nil
---@field autocmd_group               integer|nil
local watchers = {
  workspace = nil,
  fs = {},
  interval = nil,
  autocmd_group = nil,
}

local bootstrap_done = false ---@type boolean
local refreshing = false ---@type boolean
local pending_refresh = false ---@type boolean

---@param stage_state                 "staged"|"unstaged"|"mixed"|nil
---@param codes                       table<string, boolean>|nil
---@param summary                     string|nil
---@param display                     string|nil
---@param categories                  table<string, boolean>|nil
---@return string|nil
local function resolve_highlight(stage_state, codes, summary, display, categories)
  local resolved = categories ---@type table<string, boolean>|nil
  if type(resolved) ~= "table" then
    resolved = std.git.collect_entry_categories(stage_state, codes)
  end

  resolved = resolved or {}

  if resolved.deleted then
    return GIT_STATUS_HIGHLIGHT.D
  end
  if resolved.conflict then
    return GIT_STATUS_HIGHLIGHT.U
  end
  if resolved.unstaged then
    return "f_ft_git_unstaged"
  end
  if resolved.staged then
    return "f_ft_git_staged"
  end
  if resolved.modified then
    return GIT_STATUS_HIGHLIGHT.M
  end
  if resolved.added then
    return GIT_STATUS_HIGHLIGHT.A
  end
  if resolved.untracked then
    return GIT_STATUS_HIGHLIGHT["?"]
  end
  if resolved.ignored then
    return GIT_STATUS_HIGHLIGHT["!"]
  end

  if summary ~= nil then
    local hl = GIT_STATUS_HIGHLIGHT[summary]
    if hl ~= nil then
      return hl
    end
  end

  if display ~= nil and #display > 0 then
    return GIT_STATUS_HIGHLIGHT[display:sub(1, 1)]
  end

  return nil
end

---@return integer
local function git_status_now()
  if vim.uv.now then
    ---@diagnostic disable-next-line: undefined-field
    return vim.uv.now()
  end
  if vim.uv.hrtime then
    ---@diagnostic disable-next-line: undefined-field
    return math.floor(vim.uv.hrtime() / 1e6)
  end
  ---@diagnostic disable-next-line: undefined-field
  return math.floor(vim.fn.reltimefloat(vim.fn.reltime()) * 1000)
end

---@class eve.state.git.dirinfo
---@field summary                     string|nil
---@field stage                       std.git.StageState
---@field codes                       table<string, boolean>

---@param dir_info                    table<string, eve.state.git.dirinfo>
---@param path                        string
---@return                            eve.state.git.dirinfo
local function dir_info_get(dir_info, path)
  local info = dir_info[path]
  if info == nil then
    info = { summary = nil, stage = nil, codes = {} }
    dir_info[path] = info
  end
  return info
end

---@param info                        eve.state.git.dirinfo
---@return string
local function dir_info_collect_display(info)
  return std.git.codes_to_display(info.codes)
end

---@param info                        eve.state.git.dirinfo
---@param entry                       std.git.StatusEntry
local function dir_info_update(info, entry)
  local summary = entry.summary ---@type string|nil
  if summary ~= nil then
    info.summary = std.git.merge_priority_status(info.summary, summary)
  end
  info.stage = std.git.combine_stage(info.stage, entry.stage)

  local set = info.codes ---@type table<string, boolean>
  for code, enabled in pairs(entry.codes) do
    if enabled then
      set[code] = true
    end
  end
end

---@param filepath                    string
---@param workspace                   string|nil
---@param dir_info                    table<string, eve.state.git.dirinfo>
---@param entry                       std.git.StatusEntry
local function git_status_propagate_directory(filepath, workspace, dir_info, entry)
  local has_codes = type(entry.codes) == "table" and next(entry.codes) ~= nil ---@type boolean
  if entry.summary == nil and entry.stage == nil and not has_codes then
    return
  end

  local dirpath = std.path.dirname(filepath) ---@type string|nil
  while dirpath ~= nil and #dirpath > 0 do
    local normalized_dir = std.path.normalize(dirpath) ---@type string
    local info = dir_info_get(dir_info, normalized_dir)
    dir_info_update(info, entry)

    if workspace ~= nil and normalized_dir == workspace then
      break
    end

    local parent = std.path.dirname(normalized_dir) ---@type string|nil
    if parent == nil or parent == "" or parent == normalized_dir then
      break
    end
    dirpath = parent
  end
end

local refresh_git_status_impl ---@type fun()
local refresh_debounced_general ---@type fun()
local refresh_debounced_fs ---@type fun()

local function clear_fs_watchers()
  for _, unwatch in ipairs(watchers.fs) do
    pcall(unwatch)
  end
  watchers.fs = {}
end

local function clear_interval()
  if watchers.interval ~= nil then
    std.timer.clear_timer(watchers.interval)
    watchers.interval = nil
  end
end

---@param workspace                   string|nil
local function set_workspace_watchers(workspace)
  if watchers.workspace == workspace then
    return
  end

  clear_fs_watchers()
  watchers.workspace = workspace

  if workspace == nil then
    return
  end

  local git_dir = std.path.join(workspace, ".git") ---@type string
  if not std.path.is_exist(git_dir) then
    return
  end

  local function attach_watch(target, callback, subject)
    local ok, unwatch = pcall(function()
      return std.fs.watch_file({
        filepath = target,
        on_event = callback,
        on_error = function(path, err, unwatch_cb)
          std.reporter.warn({
            from = __module_name__,
            subject = subject,
            message = "Failed to watch git file changes.",
            details = { filepath = path, error = err },
          })
          unwatch_cb()
        end,
      })
    end)

    if ok and type(unwatch) == "function" then
      watchers.fs[#watchers.fs + 1] = unwatch
    end
  end

  local index_path = std.path.join(git_dir, "index") ---@type string
  if std.path.is_exist(index_path) then
    attach_watch(index_path, function()
      refresh_debounced_general()
    end, "watch_git_index")
  end

  local head_path = std.path.join(git_dir, "HEAD") ---@type string
  if std.path.is_exist(head_path) then
    attach_watch(head_path, function()
      refresh_debounced_general()
    end, "watch_git_head")
  end

  local logs_dir = std.path.join(git_dir, "logs") ---@type string
  if std.path.is_exist_dirpath(logs_dir) then
    local head_log_path = std.path.join(logs_dir, "HEAD") ---@type string
    if std.path.is_exist(head_log_path) then
      attach_watch(head_log_path, function()
        refresh_debounced_general()
      end, "watch_git_logs")
    end
  end

  if std.path.is_exist_dirpath(workspace) then
    attach_watch(workspace, function()
      refresh_debounced_fs()
    end, "watch_git_workspace")
  end
end

local function ensure_interval()
  if watchers.interval ~= nil then
    return
  end

  local timer = std.timer.set_interval(function()
    refresh_git_status_impl()
  end, REFRESH_INTERVAL_MS)

  if timer ~= nil then
    watchers.interval = timer
  end
end

local function setup_autocmd()
  if watchers.autocmd_group ~= nil then
    return
  end

  local group = vim.api.nvim_create_augroup("EveGitStatusCache", { clear = true }) ---@type integer
  watchers.autocmd_group = group

  vim.api.nvim_create_autocmd({ "BufWritePost", "FileChangedShellPost", "FocusGained", "DirChanged" }, {
    group = group,
    callback = function()
      refresh_debounced_general()
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      clear_fs_watchers()
      clear_interval()
    end,
  })
end

refresh_debounced_general = std.timer.debounce(function()
  refresh_git_status_impl()
end, REFRESH_DEBOUNCE_MS)

refresh_debounced_fs = std.timer.debounce(function()
  refresh_git_status_impl()
end, FS_WATCH_DEBOUNCE_MS)

---@param workspace                   string|nil
---@param status_table                table<string, std.git.StatusEntry>
---@param status_groups               table<string, table<string, boolean>>|nil
local function apply_status(workspace, status_table, status_groups)
  local normalized_workspace = workspace ~= nil and std.path.normalize(workspace) or nil ---@type string|nil

  local status_entries = {} ---@type table<string, std.git.StatusEntry>
  local file_status = {} ---@type table<string, string>
  local file_display = {} ---@type table<string, string>
  local file_summary = {} ---@type table<string, string|nil>
  local file_stage = {} ---@type table<string, "staged"|"unstaged"|"mixed"|nil>
  local dir_info = {} ---@type table<string, eve.state.git.dirinfo>
  local status_groups_copy = {} ---@type table<string, table<string, boolean>>

  for filepath, entry in pairs(status_table) do
    if type(filepath) == "string" and type(entry) == "table" then
      local normalized_filepath = std.path.normalize(filepath) ---@type string
      local display = entry.display or "" ---@type string
      local summary = entry.summary ---@type string|nil
      local stage_state = entry.stage ---@type "staged"|"unstaged"|"mixed"|nil

      entry.path = normalized_filepath
      status_entries[normalized_filepath] = entry
      file_status[normalized_filepath] = display
      file_display[normalized_filepath] = display
      if summary ~= nil then
        file_summary[normalized_filepath] = summary
      end
      if stage_state ~= nil then
        file_stage[normalized_filepath] = stage_state
      end

      git_status_propagate_directory(normalized_filepath, normalized_workspace, dir_info, entry)
    end
  end

  local dir_display = {} ---@type table<string, string>
  local dir_summary = {} ---@type table<string, string|nil>
  local dir_stage = {} ---@type table<string, "staged"|"unstaged"|"mixed"|nil>
  local dir_codes = {} ---@type table<string, table<string, boolean>>
  for dirpath, info in pairs(dir_info) do
    local display = dir_info_collect_display(info) ---@type string
    dir_display[dirpath] = display
    if info.summary ~= nil then
      dir_summary[dirpath] = info.summary
    end
    if info.stage ~= nil then
      dir_stage[dirpath] = info.stage
    end
    local codes_copy = {}
    for code, enabled in pairs(info.codes) do
      if enabled then
        codes_copy[code] = true
      end
    end
    dir_codes[dirpath] = codes_copy
  end

  if type(status_groups) == "table" then
    for category, set in pairs(status_groups) do
      local bucket = {} ---@type table<string, boolean>
      if type(set) == "table" then
        for filepath, enabled in pairs(set) do
          if enabled then
            local normalized_filepath = std.path.normalize(filepath) ---@type string
            bucket[normalized_filepath] = true
          end
        end
      end
      status_groups_copy[category] = bucket
    end
  end
  local category_list = std.git.STATUS_CATEGORY_LIST ---@type string[]|nil
  if type(category_list) == "table" then
    for _, category in ipairs(category_list) do
      if status_groups_copy[category] == nil then
        status_groups_copy[category] = {}
      end
    end
  end

  cache.workspace = normalized_workspace
  cache.status_table = status_entries
  cache.status_groups = status_groups_copy
  cache.file_status = file_status
  cache.file_display = file_display
  cache.file_summary = file_summary
  cache.file_stage = file_stage
  cache.dir_display = dir_display
  cache.dir_summary = dir_summary
  cache.dir_stage = dir_stage
  cache.dir_codes = dir_codes
  cache.last_refresh = git_status_now()
  cache.initialized = true
end

local function ensure_bootstrap()
  if bootstrap_done then
    return
  end
  bootstrap_done = true
  setup_autocmd()
  ensure_interval()
end

refresh_git_status_impl = function()
  ensure_bootstrap()

  if refreshing then
    pending_refresh = true
    return
  end

  refreshing = true

  local ok, workspace, status_table, status_groups = pcall(std.git.collect_status, { base = "HEAD" })
  if ok and type(status_table) == "table" then
    apply_status(workspace, status_table, status_groups)

    if std.path.is_git_repo() and cache.workspace ~= nil then
      set_workspace_watchers(cache.workspace)
    else
      set_workspace_watchers(nil)
    end
  end

  refreshing = false

  if pending_refresh then
    pending_refresh = false
    vim.schedule(refresh_git_status_impl)
  end
end

local function ensure_cache_ready()
  ensure_bootstrap()
  if not cache.initialized then
    refresh_git_status_impl()
  end
end

---@param base                         string|nil
---@return string
---@return table<string, string>
function M.status(base)
  local ok, workspace, status_table = pcall(std.git.collect_status, { base = base }) ---@type boolean, string, table<string, std.git.StatusEntry>
  if not ok then
    return std.path.workspace(), {}
  end
  if type(status_table) ~= "table" then
    return workspace, {}
  end

  local result = {} ---@type table<string, string>
  for filepath, entry in pairs(status_table) do
    if type(filepath) == "string" and type(entry) == "table" then
      result[filepath] = entry.display or ""
    end
  end

  return workspace, result
end

---@return table<string, std.git.StatusEntry>
function M.status_table()
  ensure_cache_ready()
  return cache.status_table
end

---@return table<string, table<string, boolean>>
function M.status_groups()
  ensure_cache_ready()
  return cache.status_groups
end

---@param status                      string
---@return string
function M.extract_parent_status(status)
  return std.git.extract_parent_status(status)
end

---@param filepath                    string
---@param filetype                    "file"|"directory"|nil
---@return string|nil
---@return string|nil
function M.resolve_status(filepath, filetype)
  ensure_cache_ready()

  if type(filepath) ~= "string" or #filepath < 1 then
    return nil, nil
  end

  local normalized_filepath = std.path.normalize(filepath) ---@type string
  local kind = filetype or "file" ---@type string

  if kind == "directory" then
    local display = cache.dir_display[normalized_filepath] ---@type string|nil
    if display == nil or #display < 1 then
      return nil, nil
    end
    local summary = cache.dir_summary[normalized_filepath] ---@type string|nil
    local stage_state = cache.dir_stage[normalized_filepath] ---@type string|nil
    local codes = cache.dir_codes[normalized_filepath] ---@type table<string, boolean>|nil
    local highlight = resolve_highlight(stage_state, codes, summary, display, nil) ---@type string|nil
    return display, highlight
  end

  local display = cache.file_display[normalized_filepath] ---@type string|nil
  if display == nil or #display < 1 then
    return nil, nil
  end
  local summary = cache.file_summary[normalized_filepath] ---@type string|nil
  local stage_state = cache.file_stage[normalized_filepath] ---@type string|nil
  local entry = cache.status_table[normalized_filepath] ---@type std.git.StatusEntry|nil
  local codes = entry and entry.codes or nil ---@type table<string, boolean>|nil
  local categories = entry and entry.categories or nil ---@type table<string, boolean>|nil
  local highlight = resolve_highlight(stage_state, codes, summary, display, categories) ---@type string|nil
  return display, highlight
end

---@param filepath                    string
---@param filetype                    "file"|"directory"|nil
---@param offset                      integer
---@param highlights                  std.t.IHighlightInline[]
---@return string
---@return string|nil
function M.calc_status_info(filepath, filetype, offset, highlights)
  ensure_cache_ready()

  if type(highlights) ~= "table" then
    return "", nil
  end

  local display, highlight = M.resolve_status(filepath, filetype)
  if display == nil or #display < 1 then
    return "", nil
  end

  local part = " " .. display ---@type string
  local leading_space_colr = offset + 1 ---@type integer
  highlights[#highlights + 1] = { coll = offset, colr = leading_space_colr, hlname = DEFAULT_GIT_STATUS_HL }

  local status_offset = leading_space_colr ---@type integer
  local staged_len = 0 ---@type integer
  local normalized_filepath = std.path.normalize(filepath) ---@type string
  local entry = cache.status_table[normalized_filepath] ---@type std.git.StatusEntry|nil
  if entry ~= nil then
    staged_len = #(entry.staged_display or "")
  end
  for index = 1, #display do
    local char = display:sub(index, index) ---@type string
    local hlname = GIT_STATUS_HIGHLIGHT[char] or DEFAULT_GIT_STATUS_HL ---@type string
    local is_staged_char = index <= staged_len ---@type boolean
    if is_staged_char and char ~= "D" and char ~= "U" then
      hlname = "f_ft_git_staged"
    end
    local coll = status_offset + index - 1 ---@type integer
    local colr = coll + 1 ---@type integer
    highlights[#highlights + 1] = { coll = coll, colr = colr, hlname = hlname }
  end

  return part, highlight
end

---@return table<string, string>
function M.snapshot()
  ensure_cache_ready()
  return cache.file_status
end

---@param force                       boolean|nil
function M.refresh_git_status(force)
  pending_refresh = false
  if force then
    cache.initialized = false
  end
  refresh_git_status_impl()
end

M.refresh = M.refresh_git_status

---@return integer
function M.last_refreshed_at()
  ensure_cache_ready()
  return cache.last_refresh
end

return M
