---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.data" ---@type string

---@class era.m.diffview.data
local M = {}

----------------------------------------------------------------------------------------------------
-- Local helper functions
----------------------------------------------------------------------------------------------------

---Throw if token is cancelled
---@param token                        ?stl.c.CancellationToken
local function check_token(token)
  if token then
    token:throw_if_cancelled()
  end
end

---Convert era.m.git.StatusEntry to era.m.diffview.IFileEntry
---@param entry                       era.m.git.StatusEntry
---@param stage_type                  stl.m.diffview.StageTypeEnum
---@return era.m.diffview.IFileEntry
local function convert_status_entry(entry, stage_type)
  local codes = stage_type == "staged" and entry.staged or entry.unstaged or entry.codes
  local prev_filepath = nil ---@type string|nil
  if stage_type == "staged" then
    prev_filepath = entry.staged_prev_relative
  else
    prev_filepath = entry.unstaged_prev_relative
  end

  ---Determine primary status code from codes table
  ---@param c                          table<string, boolean>|nil
  ---@return string
  local function get_status(c)
    if not c then
      return "M"
    end
    local priority = { "D", "A", "?", "R", "C", "M", "T", "U" }
    for _, code in ipairs(priority) do
      if c[code] then
        return code
      end
    end
    return "M"
  end

  ---@type era.m.diffview.IFileEntry
  return {
    filepath = entry.relative,
    status = get_status(codes),
    stage_type = stage_type,
    insertions = nil,
    deletions = nil,
    prev_filepath = prev_filepath,
  }
end

---@param line                        string
---@return string|nil status, string|nil filepath, string|nil prev_filepath
local function parse_name_status_line(line)
  -- Rename/copy format: "R100\told/path\tnew/path" (tab separated)
  local status_ext, prev, current = line:match("^(%u)%d*\t([^\t]+)\t(.+)$")
  if status_ext == "R" or status_ext == "C" then
    return status_ext, current, prev
  end

  -- Normal format: "M\tfilepath" or "M filepath"
  local status, filepath = line:match("^(%u)\t(.+)$")
  if status then
    return status, filepath, nil
  end

  status, filepath = line:match("^(%u)%s+(.+)$")
  if status then
    return status, filepath, nil
  end

  return nil, nil, nil
end

---@param line                        string
---@return integer|nil ins, integer|nil del, string|nil filepath, string|nil prev_filepath
local function parse_numstat_line(line)
  -- Rename/copy format: "10\t5\told/path\tnew/path" (tab separated)
  local ins_ext, del_ext, prev, current = line:match("^(%d+)\t(%d+)\t([^\t]+)\t(.+)$")
  if ins_ext and del_ext and current then
    return tonumber(ins_ext) or 0, tonumber(del_ext) or 0, current, prev
  end

  -- Normal format: "10\t5\tfilepath"
  local ins, del, filepath = line:match("^(%d+)\t(%d+)\t(.+)$")
  if ins and del and filepath then
    return tonumber(ins) or 0, tonumber(del) or 0, filepath, nil
  end

  return nil, nil, nil, nil
end

---Parse NUL-delimited numstat output. Rename/copy records use an empty path field
---followed by the previous and current paths as separate records.
---@param lines                       string[]
---@return table<string, { insertions: integer, deletions: integer }>
local function parse_numstat_output(lines)
  local output = table.concat(lines, "\n") ---@type string
  local stats = {} ---@type table<string, { insertions: integer, deletions: integer }>

  if not output:find("\0", 1, true) then
    for _, line in ipairs(lines) do
      local insertions, deletions, filepath = parse_numstat_line(line)
      if insertions and deletions and filepath then
        stats[filepath] = { insertions = insertions, deletions = deletions }
      end
    end
    return stats
  end

  local records = vim.split(output, "\0", { plain = true }) ---@type string[]
  local index = 1 ---@type integer
  while index <= #records do
    local record = records[index]
    local insertions_text, deletions_text, filepath = record:match("^([%d-]+)\t([%d-]+)\t(.*)$")
    if insertions_text == nil or deletions_text == nil or filepath == nil then
      index = index + 1
    else
      if filepath == "" then
        filepath = records[index + 2]
        index = index + 3
      else
        index = index + 1
      end

      local insertions = tonumber(insertions_text) ---@type integer|nil
      local deletions = tonumber(deletions_text) ---@type integer|nil
      if insertions and deletions and filepath and filepath ~= "" then
        stats[filepath] = { insertions = insertions, deletions = deletions }
      end
    end
  end

  return stats
end

---@param entries                      era.m.diffview.IFileEntry[]
---@param stats                        table<string, era.m.git.status.INumstat>
---@param stage_type                   stl.m.diffview.StageTypeEnum
local function apply_numstat_map(entries, stats, stage_type)
  for _, entry in ipairs(entries) do
    if entry.stage_type == stage_type then
      local stat = stats[entry.filepath]
      if stat then
        entry.insertions = stat.insertions
        entry.deletions = stat.deletions
      end
    end
  end
end

---@param result                       stl.git.exec.IResult|nil
---@return boolean
local function git_succeeded(result)
  return type(result) == "table" and result.code == 0
end

---@param args                         string[]
---@param opts                         stl.git.exec.IExecOpts
---@param token                        stl.c.CancellationToken|nil
---@return stl.git.exec.IResult
local function exec_git(args, opts, token)
  return stl.async.await_all({ stl.git.exec.exec(args, opts, token) })[1]
end

---@param temp_dir                     string
local function cleanup_temp_dir(temp_dir)
  if vim.fn.delete(temp_dir, "rf") == 0 or not vim.uv.fs_stat(temp_dir) then
    return
  end

  vim.defer_fn(function()
    if vim.fn.delete(temp_dir, "rf") ~= 0 and vim.uv.fs_stat(temp_dir) then
      stl.reporter.warn({
        from = __module_name__,
        subject = "fetch_numstat",
        message = "Unable to remove temporary Git index directory: " .. temp_dir,
      })
    end
  end, 100)
end

---Use an isolated intent-to-add index so Git computes every untracked stat in one diff.
---Untracked stats are auxiliary: non-cancellation failures degrade to unknown stats
---instead of blocking the complete Changes pane snapshot.
---@async
---@param entries                      era.m.diffview.IFileEntry[]
---@param cwd                          string
---@param token                        stl.c.CancellationToken|nil
---@return stl.git.exec.IResult|nil
local function fetch_untracked_numstat(entries, cwd, token)
  local paths = {} ---@type string[]
  for _, entry in ipairs(entries) do
    if entry.stage_type == "unstaged" and entry.status == "?" then
      paths[#paths + 1] = entry.filepath
    end
  end
  if #paths == 0 then
    return nil
  end

  check_token(token)

  local temp_dir = vim.fn.tempname() ---@type string
  local temp_index = temp_dir .. "/index" ---@type string
  if vim.fn.mkdir(temp_dir, "p") ~= 1 then
    return nil
  end
  -- Keep the index path absent: `git add` creates a new empty alternate index, avoiding a separate `read-tree`.
  local env = { GIT_INDEX_FILE = temp_index } ---@type table<string, string>
  local ok, result = xpcall(function()
    local pathspec = table.concat(paths, "\0") .. "\0" ---@type string
    local add_result = exec_git(
      { "--literal-pathspecs", "add", "-N", "--pathspec-from-file=-", "--pathspec-file-nul" },
      { cwd = cwd, raw = true, env = env, stdin = pathspec },
      token
    )
    check_token(token)
    if not git_succeeded(add_result) then
      return nil
    end

    local diff_result = exec_git({ "diff", "--numstat", "-z", "--" }, { cwd = cwd, raw = true, env = env }, token)
    check_token(token)
    if not git_succeeded(diff_result) then
      return nil
    end
    return diff_result
  end, function(err)
    return err
  end)

  cleanup_temp_dir(temp_dir)
  if not ok then
    check_token(token)
    error(result, 0)
  end
  return result
end

----------------------------------------------------------------------------------------------------
-- Async data fetching (Future/await pattern)
----------------------------------------------------------------------------------------------------

---Fetch diff entries (staged and unstaged files).
---@async
---@param token                       ?stl.c.CancellationToken
---@return era.m.diffview.IFileEntry[]
function M.fetch_diff_entries(token)
  check_token(token)

  local result = era.m.git.status.collect({ include_numstat = true }, token):await()
  local status_map = result and result.status_map or nil

  check_token(token)

  local entries = M.__convert_status_to_entries__(status_map)
  if #entries == 0 then
    return entries
  end

  local numstats = assert(result and result.numstats, "Git status snapshot is missing requested numstat")
  apply_numstat_map(entries, numstats.staged, "staged")
  apply_numstat_map(entries, numstats.unstaged, "unstaged")

  return M.__fetch_untracked_numstat__(entries, token)
end

---Convert status map to file entries.
---@param status_map                   table<string, era.m.git.StatusEntry>|nil
---@return era.m.diffview.IFileEntry[]
function M.__convert_status_to_entries__(status_map)
  local entries = {} ---@type era.m.diffview.IFileEntry[]

  if not status_map then
    return entries
  end

  for _, status_entry in pairs(status_map) do
    if next(status_entry.staged or {}) ~= nil then
      local entry = convert_status_entry(status_entry, "staged")
      entries[#entries + 1] = entry
    end

    if next(status_entry.unstaged or {}) ~= nil then
      local entry = convert_status_entry(status_entry, "unstaged")
      entries[#entries + 1] = entry
    end
  end

  return entries
end

---@param entry                       era.m.diffview.IFileEntry
---@return string
local function get_diff_entry_id(entry)
  return table.concat({ entry.stage_type or "", entry.filepath }, "\0")
end

---@param left                        era.m.diffview.IFileEntry
---@param right                       era.m.diffview.IFileEntry
---@return boolean
local function equal_diff_entry(left, right)
  return left.filepath == right.filepath
    and left.stage_type == right.stage_type
    and left.status == right.status
    and left.insertions == right.insertions
    and left.deletions == right.deletions
    and left.prev_filepath == right.prev_filepath
end

---Compare complete Changes snapshots independent of Git collection order.
---Unknown line stats (`nil`) remain distinct from known zero values.
---@param left                        era.m.diffview.IFileEntry[]
---@param right                       era.m.diffview.IFileEntry[]
---@return boolean
function M.equal_diff_entries(left, right)
  if left == right then
    return true
  end
  if #left ~= #right then
    return false
  end

  local left_by_id = {} ---@type table<string, era.m.diffview.IFileEntry>
  for _, entry in ipairs(left) do
    local id = get_diff_entry_id(entry)
    if left_by_id[id] then
      return false
    end
    left_by_id[id] = entry
  end

  local seen = {} ---@type table<string, boolean>
  for _, entry in ipairs(right) do
    local id = get_diff_entry_id(entry)
    if seen[id] or not left_by_id[id] or not equal_diff_entry(left_by_id[id], entry) then
      return false
    end
    seen[id] = true
  end
  return true
end

---@param entries                     era.m.diffview.IFileEntry[]
---@param status_map                  table<string, era.m.git.StatusEntry>
---@return boolean
function M.matches_status_entries(entries, status_map)
  local expected = M.__convert_status_to_entries__(status_map)
  if #entries ~= #expected then
    return false
  end

  local entry_ids = {} ---@type table<string, boolean>
  for _, entry in ipairs(entries) do
    local id = table.concat({ entry.stage_type or "", entry.status, entry.filepath, entry.prev_filepath or "" }, "\0")
    entry_ids[id] = true
  end

  for _, entry in ipairs(expected) do
    local id = table.concat({ entry.stage_type or "", entry.status, entry.filepath, entry.prev_filepath or "" }, "\0")
    if not entry_ids[id] then
      return false
    end
  end
  return true
end

---Fetch untracked numstat and update entries with insertions/deletions.
---@async
---@param entries                     era.m.diffview.IFileEntry[]
---@param token                       ?stl.c.CancellationToken
---@return era.m.diffview.IFileEntry[]
function M.__fetch_untracked_numstat__(entries, token)
  if #entries == 0 then
    return entries
  end

  check_token(token)

  local cwd = dot.path.workspace()
  local untracked_result = fetch_untracked_numstat(entries, cwd, token)
  if untracked_result then
    M.__apply_numstat_stats__(entries, untracked_result, "unstaged")
  end

  return entries
end

---Apply numstat stats to entries.
---@param entries                      era.m.diffview.IFileEntry[]
---@param result                       { lines: string[], code: integer }
---@param stage_type                   stl.m.diffview.StageTypeEnum
---@return nil
function M.__apply_numstat_stats__(entries, result, stage_type)
  if not result or result.code ~= 0 then
    return
  end

  local stats = parse_numstat_output(result.lines)
  apply_numstat_map(entries, stats, stage_type)
end

---Fetch total commit count.
---@async
---@param path_filter                  string|nil                      Optional path filter
---@param token                        ?stl.c.CancellationToken
---@return integer
function M.fetch_log_count(path_filter, token)
  check_token(token)

  local workspace = dot.path.workspace()

  -- Note: git rev-list --count does not support --follow, so we use git log for path filtering
  if path_filter then
    local args = { "log", "--format=%H", "--follow", "--", path_filter }
    local result = stl.git.exec.exec(args, { cwd = workspace }, token):await()

    check_token(token)

    if result.code == 0 then
      -- Count non-empty lines
      local count = 0
      for _, line in ipairs(result.lines) do
        if line ~= "" then
          count = count + 1
        end
      end
      return count
    end

    return 0
  end

  local args = { "rev-list", "--count", "HEAD" }
  local result = stl.git.exec.exec(args, { cwd = workspace }, token):await()

  check_token(token)

  if result.code == 0 and result.lines[1] then
    return tonumber(result.lines[1]) or 0
  end

  return 0
end

---Fetch commits for a specific page (with shortstat).
---@async
---@param page                         integer                         Page number (1-indexed)
---@param per_page                     integer                         Commits per page
---@param path_filter                  string|nil                      Optional path filter
---@param token                        ?stl.c.CancellationToken
---@return era.m.diffview.ICommit[]
function M.fetch_log_page(page, per_page, path_filter, token)
  check_token(token)

  local workspace = dot.path.workspace()
  local skip = (page - 1) * per_page

  -- If we have a path filter, use file-specific logic
  if path_filter then
    return M.__fetch_log_page_with_path__(workspace, skip, per_page, path_filter, token)
  end

  local args = {
    "log",
    "--pretty=format:%H%x00%h%x00%an%x00%ai%x00%s",
    "--skip=" .. tostring(skip),
    "-n",
    tostring(per_page),
  }

  local result = stl.git.exec.exec(args, { cwd = workspace }, token):await()

  check_token(token)

  local commits = {} ---@type era.m.diffview.ICommit[]
  local commits_map = {} ---@type table<string, era.m.diffview.ICommit>

  if result.code == 0 then
    for _, line in ipairs(result.lines) do
      local hash, abbrev, author, date_str, message = line:match("^([^%z]+)%z([^%z]+)%z([^%z]+)%z([^%z]+)%z(.*)$")
      if hash then
        ---@type era.m.diffview.ICommit
        local commit = {
          hash = hash,
          abbrev_hash = abbrev,
          author = author,
          date = M.__parse_git_date__(date_str),
          message = message,
          files = nil,
          total_insertions = nil,
          total_deletions = nil,
        }
        commits[#commits + 1] = commit
        commits_map[hash] = commit
      end
    end
  end

  -- Fetch shortstat for this page
  return M.__fetch_log_page_shortstat__(commits, commits_map, skip, per_page, workspace, token)
end

---Fetch commits for a specific page with path filter.
---@async
---@param workspace                    string
---@param skip                         integer
---@param per_page                     integer
---@param path_filter                  string
---@param token                        ?stl.c.CancellationToken
---@return era.m.diffview.ICommit[]
function M.__fetch_log_page_with_path__(workspace, skip, per_page, path_filter, token)
  check_token(token)

  -- Fetch with --name-status for file status
  local args_status = {
    "log",
    "--pretty=format:%H%x00%h%x00%an%x00%ai%x00%s",
    "--name-status",
    "--follow",
    "--skip=" .. tostring(skip),
    "-n",
    tostring(per_page),
    "--",
    path_filter,
  }

  local status_result = stl.git.exec.exec(args_status, { cwd = workspace }, token):await()

  check_token(token)

  local commits_map = {} ---@type table<string, era.m.diffview.ICommit>
  local commits_order = {} ---@type string[]

  if status_result.code == 0 then
    local i = 1
    while i <= #status_result.lines do
      local line = status_result.lines[i]
      local hash, abbrev, author, date_str, message = line:match("^([^%z]+)%z([^%z]+)%z([^%z]+)%z([^%z]+)%z(.*)$")
      if hash then
        ---@type era.m.diffview.ICommit
        local commit = {
          hash = hash,
          abbrev_hash = abbrev,
          author = author,
          date = M.__parse_git_date__(date_str),
          message = message,
          files = nil,
          file_status = nil,
          filepath = nil,
          parent_filepath = nil,
          file_insertions = nil,
          file_deletions = nil,
        }

        -- Next non-empty line should be the status line
        i = i + 1
        while i <= #status_result.lines do
          local status_line = status_result.lines[i]
          if status_line == "" then
            i = i + 1
            break
          end
          local status, path_current, path_prev = parse_name_status_line(status_line)
          if status and path_current then
            commit.file_status = status
            commit.filepath = path_current
            commit.parent_filepath = path_prev
          end
          i = i + 1
        end

        commits_map[hash] = commit
        commits_order[#commits_order + 1] = hash
      else
        i = i + 1
      end
    end
  end

  -- Now fetch numstat for insertions/deletions
  local args_numstat = {
    "log",
    "--pretty=format:%H",
    "--numstat",
    "--follow",
    "--skip=" .. tostring(skip),
    "-n",
    tostring(per_page),
    "--",
    path_filter,
  }

  local numstat_result = stl.git.exec.exec(args_numstat, { cwd = workspace }, token):await()

  check_token(token)

  if numstat_result.code == 0 then
    local current_hash = nil ---@type string|nil
    for _, numstat_line in ipairs(numstat_result.lines) do
      if numstat_line == "" then
        current_hash = nil
      elseif numstat_line:match("^%x+$") then
        current_hash = numstat_line
      elseif current_hash then
        local ins, del, path_current, path_prev = parse_numstat_line(numstat_line)
        local commit = path_current and commits_map[current_hash] or nil
        if ins and del and commit then
          commit.file_insertions = ins
          commit.file_deletions = del
          if not commit.filepath then
            commit.filepath = path_current
            commit.parent_filepath = path_prev
          end
        end
      end
    end
  end

  -- Build final commits array in order
  local commits = {} ---@type era.m.diffview.ICommit[]
  for _, hash in ipairs(commits_order) do
    local commit = commits_map[hash]
    if commit and not commit.filepath then
      commit.filepath = path_filter
    end
    commits[#commits + 1] = commit
  end

  -- Fetch shortstat for total_files_changed, total_insertions, total_deletions
  return M.__fetch_log_page_with_path_shortstat__(commits, commits_map, path_filter, skip, per_page, workspace, token)
end

---Fetch shortstat for a page of commits with path filter.
---@async
---@param commits                      era.m.diffview.ICommit[]
---@param commits_map                  table<string, era.m.diffview.ICommit>
---@param path_filter                  string
---@param skip                         integer
---@param per_page                     integer
---@param workspace                    string
---@param token                        ?stl.c.CancellationToken
---@return era.m.diffview.ICommit[]
function M.__fetch_log_page_with_path_shortstat__(commits, commits_map, path_filter, skip, per_page, workspace, token)
  if #commits == 0 then
    return commits
  end

  check_token(token)

  local args = {
    "log",
    "--pretty=format:%H",
    "--shortstat",
    "--follow",
    "--skip=" .. tostring(skip),
    "-n",
    tostring(per_page),
    "--",
    path_filter,
  }

  local result = stl.git.exec.exec(args, { cwd = workspace }, token):await()

  check_token(token)

  if result.code == 0 then
    M.__apply_shortstat__(commits_map, result.lines)
  end

  return commits
end

---Apply shortstat lines to commits map.
---@param commits_map                  table<string, era.m.diffview.ICommit>
---@param lines                        string[]
function M.__apply_shortstat__(commits_map, lines)
  local current_hash = nil ---@type string|nil
  for _, line in ipairs(lines) do
    if line == "" then
      current_hash = nil
    elseif line:match("^%x+$") then
      current_hash = line
    elseif current_hash then
      -- Parse shortstat line: " 3 files changed, 10 insertions(+), 5 deletions(-)"
      local files = line:match("(%d+) file") or "0"
      local ins = line:match("(%d+) insertion") or "0"
      local del = line:match("(%d+) deletion") or "0"
      local commit = commits_map[current_hash]
      if commit then
        commit.total_files_changed = tonumber(files) or 0
        commit.total_insertions = tonumber(ins) or 0
        commit.total_deletions = tonumber(del) or 0
      end
    end
  end
end

---Fetch shortstat for a page of commits.
---@async
---@param commits                     era.m.diffview.ICommit[]
---@param commits_map                 table<string, era.m.diffview.ICommit>
---@param skip                        integer
---@param per_page                    integer
---@param workspace                   string
---@param token                       ?stl.c.CancellationToken
---@return era.m.diffview.ICommit[]
function M.__fetch_log_page_shortstat__(commits, commits_map, skip, per_page, workspace, token)
  if #commits == 0 then
    return commits
  end

  check_token(token)

  local args = {
    "log",
    "--pretty=format:%H",
    "--shortstat",
    "--skip=" .. tostring(skip),
    "-n",
    tostring(per_page),
  }

  local result = stl.git.exec.exec(args, { cwd = workspace }, token):await()

  check_token(token)

  if result.code == 0 then
    M.__apply_shortstat__(commits_map, result.lines)
  end

  return commits
end

---Fetch git log (recent commits).
---@async
---@param opts                        { limit: integer|nil }|nil
---@param token                       ?stl.c.CancellationToken
---@return era.m.diffview.ICommit[]
function M.fetch_log(opts, token)
  check_token(token)

  local limit = opts and opts.limit or 100
  local workspace = dot.path.workspace()

  local args = {
    "log",
    "--pretty=format:%H%x00%h%x00%an%x00%ai%x00%s",
    "-n",
    tostring(limit),
  }

  local result = stl.git.exec.exec(args, { cwd = workspace }, token):await()

  check_token(token)

  local commits = {} ---@type era.m.diffview.ICommit[]
  local commits_map = {} ---@type table<string, era.m.diffview.ICommit>

  if result.code == 0 then
    for _, line in ipairs(result.lines) do
      local hash, abbrev, author, date_str, message = line:match("^([^%z]+)%z([^%z]+)%z([^%z]+)%z([^%z]+)%z(.*)$")
      if hash then
        ---@type era.m.diffview.ICommit
        local commit = {
          hash = hash,
          abbrev_hash = abbrev,
          author = author,
          date = M.__parse_git_date__(date_str),
          message = message,
          files = nil,
          total_insertions = nil,
          total_deletions = nil,
        }
        commits[#commits + 1] = commit
        commits_map[hash] = commit
      end
    end
  end

  -- Fetch shortstat for total insertions/deletions per commit
  return M.__fetch_log_shortstat__(commits, commits_map, limit, workspace, token)
end

---Fetch shortstat for log commits.
---@async
---@param commits                     era.m.diffview.ICommit[]
---@param commits_map                 table<string, era.m.diffview.ICommit>
---@param limit                       integer
---@param workspace                   string
---@param token                       ?stl.c.CancellationToken
---@return era.m.diffview.ICommit[]
function M.__fetch_log_shortstat__(commits, commits_map, limit, workspace, token)
  if #commits == 0 then
    return commits
  end

  check_token(token)

  local args = {
    "log",
    "--pretty=format:%H",
    "--shortstat",
    "-n",
    tostring(limit),
  }

  local result = stl.git.exec.exec(args, { cwd = workspace }, token):await()

  check_token(token)

  if result.code == 0 then
    M.__apply_shortstat__(commits_map, result.lines)
  end

  return commits
end

---Fetch files changed in a commit.
---@async
---@param hash                        string
---@param token                       ?stl.c.CancellationToken
---@return era.m.diffview.IFileEntry[]
function M.fetch_commit_files(hash, token)
  check_token(token)

  local workspace = dot.path.workspace()

  local args = {
    "diff-tree",
    "--no-commit-id",
    "--name-status",
    "-r",
    hash,
  }

  local result = stl.git.exec.exec(args, { cwd = workspace }, token):await()

  check_token(token)

  local files = {} ---@type era.m.diffview.IFileEntry[]

  if result.code == 0 then
    for _, line in ipairs(result.lines) do
      local status, filepath, prev_filepath = parse_name_status_line(line)
      if status and filepath then
        ---@type era.m.diffview.IFileEntry
        local entry = {
          filepath = filepath,
          status = status,
          stage_type = nil,
          insertions = nil,
          deletions = nil,
          prev_filepath = prev_filepath,
        }
        files[#files + 1] = entry
      end
    end
  end

  -- Fetch numstat for this commit
  return M.__fetch_commit_numstat__(hash, files, token)
end

---Fetch numstat for a specific commit.
---@async
---@param hash                        string
---@param files                       era.m.diffview.IFileEntry[]
---@param token                       ?stl.c.CancellationToken
---@return era.m.diffview.IFileEntry[]
function M.__fetch_commit_numstat__(hash, files, token)
  if #files == 0 then
    return files
  end

  check_token(token)

  local workspace = dot.path.workspace()

  local args = {
    "diff-tree",
    "--no-commit-id",
    "--numstat",
    "-r",
    hash,
  }

  local result = stl.git.exec.exec(args, { cwd = workspace }, token):await()

  check_token(token)

  if result.code == 0 then
    local stats = {} ---@type table<string, { insertions: integer, deletions: integer }>

    for _, line in ipairs(result.lines) do
      local ins, del, filepath = parse_numstat_line(line)
      if ins and del and filepath then
        stats[filepath] = {
          insertions = ins,
          deletions = del,
        }
      end
    end

    for _, file in ipairs(files) do
      local stat = stats[file.filepath]
      if stat then
        file.insertions = stat.insertions
        file.deletions = stat.deletions
      end
    end
  end

  return files
end

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

---Parse git date string to unix timestamp
---@param date_str                    string                    Git date string (e.g., "2024-01-15 10:30:00 +0800")
---@return integer
function M.__parse_git_date__(date_str)
  if type(date_str) ~= "string" or #date_str == 0 then
    return 0
  end

  -- Parse format: "2024-01-15 10:30:00 +0800"
  local year, month, day, hour, min, sec = date_str:match("^(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
  if year then
    local time = os.time({
      year = tonumber(year) or 1970,
      month = tonumber(month) or 1,
      day = tonumber(day) or 1,
      hour = tonumber(hour) or 0,
      min = tonumber(min) or 0,
      sec = tonumber(sec) or 0,
    })
    return time or 0
  end

  return 0
end

return M
