local __module_name__ = "ghc.cmp.path" ---@type string

local uv = vim.uv

---@class ghc.cmp.path.config
---@field trailing_slash                boolean
---@field label_trailing_slash          boolean
---@field show_hidden_files_by_default  boolean
---@field debounce                      integer|false Debounce time in milliseconds
---@field request_timeout               integer Request timeout in milliseconds
---@field max_concurrent_requests       integer Maximum concurrent requests
---@field max_entries_per_scan          integer Maximum entries to process per directory scan
local config = {
  trailing_slash = true,
  label_trailing_slash = true,
  show_hidden_files_by_default = false,
  debounce = 100, -- 100ms debounce for path completion
  request_timeout = 5000, -- 5 second timeout for file operations
  max_concurrent_requests = 2, -- Limit concurrent directory scans
  max_entries_per_scan = 100, -- Limit entries processed per scan for performance
}

---@class ghc.cmp.path.util
local util = {}

---Get current timestamp in milliseconds
---@return integer
function util.timestamp()
  return math.floor(vim.uv.hrtime() / 1e6)
end

---Cancel an ongoing timer
---@param timer                        uv.uv_timer_t|nil
function util.cancel_timer(timer)
  if timer then
    timer:stop()
    timer:close()
  end
end

---@class ghc.cmp.path.context
---@field start_ts                     integer
---@field state                        table|nil
---@field active_scans                 integer
---@field last_dirname                 string|nil

---@class ghc.cmp.path
---@field opts                         ghc.cmp.path.config
---@field context                      ghc.cmp.path.context
---@field debounce_timer               uv.uv_timer_t|nil
local M = {}

function M.new(opts)
  local self = setmetatable({}, { __index = M })

  ---@type ghc.cmp.path.config
  opts = vim.tbl_deep_extend("keep", opts or {}, config)

  self.opts = opts
  self:reset_context()
  return self
end

---Reset the context
---@param ts                           integer|nil
function M:reset_context(ts)
  ts = ts or util.timestamp()

  ---@type ghc.cmp.path.context
  self.context = {
    start_ts = ts,
    state = nil,
    active_scans = 0,
    last_dirname = nil,
  }
end

---Check if we can make a new request (rate limiting)
---@return boolean
function M:can_make_request()
  return self.context.active_scans < self.opts.max_concurrent_requests
end

function M:get_trigger_characters()
  return { "@", "/" } -- Support both @ to start and / to continue
end

---Get directory path from context
---@param context                       blink.cmp.Context
---@return string|nil
function M:get_dirname(context)
  local success, result = pcall(function()
    local line_before_cursor = context.line:sub(1, context.bounds.start_col - (context.bounds.length == 0 and 1 or 0))

    -- Handle '@' prefix for both initial and continued completion
    local at_match = line_before_cursor:match("@([^%s]*)")
    if at_match then
      local cwd = std.path.cwd() ---@type string

      -- For continued completion, don't remove the filename part if it's a directory
      -- Check if the path ends with '/' (indicating it's a directory path)
      if at_match:sub(-1) == "/" then
        -- Complete path ending with /, use as is
        return std.path.resolve(cwd, at_match)
      else
        -- Remove filename part for directory completion
        local relative_path = at_match:gsub("[^/]*$", "")
        return std.path.resolve(cwd, relative_path)
      end
    end

    -- Return nil for non-@ paths, let blink.cmp handle them
    return nil
  end)

  if not success then
    std.reporter.warn({
      from = __module_name__,
      subject = "get_dirname",
      message = "Failed to parse directory path from context",
      details = { error = result, line = context.line },
    })
    return nil
  end

  return result
end

---Get last path part position
---@param path                          string
---@return number
function M:get_last_path_part(path)
  local success, result = pcall(function()
    local i = #path
    local start_pos = 1
    while i > 0 do
      local char = path:sub(i, i)

      -- Handle '@' prefix
      if char == "@" then
        start_pos = i + 1
        break
      -- Forward slash (linux/mac delimiter)
      elseif char == "/" then
        start_pos = i + 1
        break
      end

      i = i - 1
    end

    return start_pos
  end)

  if not success then
    std.reporter.warn({
      from = __module_name__,
      subject = "get_last_path_part",
      message = "Failed to parse path part",
      details = { error = result, path = path },
    })
    return 1
  end

  return result
end

---Get text edit ranges
---@param context                       blink.cmp.Context
---@return table
function M:get_text_edit_ranges(context)
  local success, result = pcall(function()
    local line_before_cursor = context.line:sub(1, context.cursor[2])
    local next_letter_is_slash = context.line:sub(context.cursor[2] + 1, context.cursor[2] + 1) == "/"

    local last_part_idx = self:get_last_path_part(line_before_cursor)

    return {
      file = {
        start = { line = context.cursor[1] - 1, character = last_part_idx - 1 },
        ["end"] = { line = context.cursor[1] - 1, character = context.cursor[2] },
      },
      directory = {
        start = { line = context.cursor[1] - 1, character = last_part_idx - 1 },
        -- replace the slash after the cursor, if it exists
        ["end"] = { line = context.cursor[1] - 1, character = context.cursor[2] + (next_letter_is_slash and 1 or 0) },
      },
    }
  end)

  if not success then
    std.reporter.warn({
      from = __module_name__,
      subject = "get_text_edit_ranges",
      message = "Failed to calculate text edit ranges",
      details = { error = result },
    })
    -- Return safe default ranges
    return {
      file = {
        start = { line = context.cursor[1] - 1, character = context.cursor[2] },
        ["end"] = { line = context.cursor[1] - 1, character = context.cursor[2] },
      },
      directory = {
        start = { line = context.cursor[1] - 1, character = context.cursor[2] },
        ["end"] = { line = context.cursor[1] - 1, character = context.cursor[2] },
      },
    }
  end

  return result
end

---Convert entry to completion item
---@param entry                         table
---@param dirname                       string
---@param range                         table
---@return table
function M:entry_to_completion_item(entry, dirname, range)
  local success, result = pcall(function()
    local is_dir = entry.type == "directory"
    local insert_text = is_dir and self.opts.trailing_slash and entry.name .. "/" or entry.name
    return {
      label = (self.opts.label_trailing_slash and is_dir) and entry.name .. "/" or entry.name,
      kind = is_dir and vim.lsp.protocol.CompletionItemKind.Folder or vim.lsp.protocol.CompletionItemKind.File,
      insertText = insert_text,
      textEdit = { newText = insert_text, range = range },
      sortText = (is_dir and "1" or "2") .. entry.name:lower(), -- Sort directories before files
      data = { path = entry.name, full_path = std.path.join(dirname, entry.name), type = entry.type, stat = entry.stat },
    }
  end)

  if not success then
    std.reporter.warn({
      from = __module_name__,
      subject = "entry_to_completion_item",
      message = "Failed to convert entry to completion item",
      details = { entry = entry, dirname = dirname, error = result },
    })
    -- Return safe fallback item
    return {
      label = entry.name or "unknown",
      kind = vim.lsp.protocol.CompletionItemKind.File,
      insertText = entry.name or "unknown",
      textEdit = { newText = entry.name or "unknown", range = range },
      sortText = "9" .. (entry.name or "unknown"):lower(),
      data = { path = entry.name or "unknown", full_path = dirname, type = "file" },
    }
  end

  return result
end

---Safely scan directory with timeout and error handling
---@param dirname                       string
---@param include_hidden                boolean
---@param timeout_ms                    integer
---@param callback                      fun(entries: table[]|nil, error: string|nil)
function M:scan_directory_async(dirname, include_hidden, timeout_ms, callback)
  local timeout_timer ---@type uv.uv_timer_t|nil
  local cancelled = false

  local function cleanup()
    util.cancel_timer(timeout_timer)
    timeout_timer = nil
    cancelled = true
  end

  local function safe_callback(entries, error)
    if cancelled then
      return
    end
    cleanup()
    callback(entries, error)
  end

  -- Set up timeout
  if timeout_ms and timeout_ms > 0 then
    timeout_timer = vim.defer_fn(function()
      safe_callback(nil, "Directory scan timeout")
    end, timeout_ms)
  end

  vim.schedule(function()
    if cancelled then
      return
    end

    local success, result = pcall(function()
      local entries = {}
      local handle = uv.fs_scandir(dirname)
      if not handle then
        return nil, "Failed to open directory"
      end

      local count = 0
      local name, type = uv.fs_scandir_next(handle)
      while name and count < self.opts.max_entries_per_scan do
        if include_hidden or name:sub(1, 1) ~= "." then
          -- Use scandir type when available, only stat when necessary
          local stat = nil
          if not type or type == "unknown" then
            stat = uv.fs_stat(std.path.join(dirname, name))
            if stat then
              type = stat.type
            end
          end

          if type then
            table.insert(entries, {
              name = name,
              type = type,
              stat = stat,
            })
            count = count + 1
          end
        end
        name, type = uv.fs_scandir_next(handle)
      end

      return entries, nil
    end)

    if success then
      safe_callback(result, nil)
    else
      std.reporter.warn({
        from = __module_name__,
        subject = "scan_directory",
        message = "Directory scan failed",
        details = { dirname = dirname, error = result },
      })
      safe_callback(nil, result)
    end
  end)

  return cleanup
end

function M:get_completions(context, callback)
  callback = vim.schedule_wrap(callback)

  local dirname = self:get_dirname(context)
  if not dirname then
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end

  -- Check if directory exists
  if not std.path.is_exist_dirpath(dirname) then
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end

  -- State management for debouncing and rate limiting
  local current_state = { bufnr = context.bufnr, cursor = context.cursor, dirname = dirname }
  if vim.deep_equal(current_state, self.context.state) then
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end

  -- Check rate limiting
  if not self:can_make_request() then
    std.reporter.warn({
      from = __module_name__,
      subject = "rate_limit",
      message = string.format("Path completion rate limited, active scans: %d", self.context.active_scans),
    })
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end

  local now = util.timestamp()
  local since = now - self.context.start_ts

  -- Debouncing
  if self.opts.debounce and since < self.opts.debounce then
    if self.debounce_timer then
      self.debounce_timer:stop()
    end
    self.debounce_timer = vim.defer_fn(function()
      self.debounce_timer = nil
      self:get_completions(context, callback)
    end, self.opts.debounce)
    return
  end

  -- Reset context for new request
  self:reset_context(now)
  self.context.state = current_state
  self.context.active_scans = self.context.active_scans + 1

  local include_hidden = self.opts.show_hidden_files_by_default
    or (string.sub(context.line, context.bounds.start_col, context.bounds.start_col) == "." and context.bounds.length == 0)
    or (
      string.sub(context.line, context.bounds.start_col - 1, context.bounds.start_col - 1) == "."
      and context.bounds.length > 0
    )

  local ranges = self:get_text_edit_ranges(context)

  -- Use new async directory scanning
  self:scan_directory_async(dirname, include_hidden, self.opts.request_timeout, function(entries, error)
    self.context.active_scans = math.max(0, self.context.active_scans - 1)

    if error then
      std.reporter.warn({
        from = __module_name__,
        subject = "directory_scan_failed",
        message = "Failed to scan directory",
        details = { dirname = dirname, error = error },
      })
      return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
    end

    if not entries then
      return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
    end

    local items = {}
    for _, entry in ipairs(entries) do
      local range = entry.type == "directory" and ranges.directory or ranges.file
      table.insert(items, self:entry_to_completion_item(entry, dirname, range))
    end

    callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
  end)
end

---Safely read file content for documentation with timeout
---@param full_path                     string
---@param timeout_ms                    integer
---@param callback                      fun(content: string|nil, error: string|nil)
function M:read_file_async(full_path, timeout_ms, callback)
  local timeout_timer ---@type uv.uv_timer_t|nil
  local cancelled = false
  local file_handle ---@type integer|nil

  local function cleanup()
    util.cancel_timer(timeout_timer)
    timeout_timer = nil
    cancelled = true
    if file_handle then
      uv.fs_close(file_handle, function() end)
      file_handle = nil
    end
  end

  local function safe_callback(content, error)
    if cancelled then
      return
    end
    cleanup()
    callback(content, error)
  end

  -- Set up timeout
  if timeout_ms and timeout_ms > 0 then
    timeout_timer = vim.defer_fn(function()
      safe_callback(nil, "File read timeout")
    end, timeout_ms)
  end

  vim.schedule(function()
    if cancelled then
      return
    end

    local success, result = pcall(function()
      file_handle = uv.fs_open(full_path, "r", 438)
      if not file_handle then
        return nil, "Failed to open file"
      end

      uv.fs_read(file_handle, 1024, 0, function(err, data)
        if cancelled then
          return
        end

        uv.fs_close(file_handle, function() end)
        file_handle = nil

        if err or not data then
          safe_callback(nil, err or "Failed to read file")
          return
        end

        local is_binary = data:find("\0")
        if is_binary then
          safe_callback("Binary file", nil)
        else
          safe_callback(data, nil)
        end
      end)

      return true, nil
    end)

    if not success then
      std.reporter.warn({
        from = __module_name__,
        subject = "read_file",
        message = "File read failed",
        details = { full_path = full_path, error = result },
      })
      safe_callback(nil, result)
    end
  end)

  return cleanup
end

function M:resolve(item, callback)
  local full_path = item.data.full_path
  if not full_path or not std.path.is_exist_filepath(full_path) then
    return callback(item)
  end

  -- Use the new async file reader with timeout
  self:read_file_async(full_path, self.opts.request_timeout, function(content, error)
    if error then
      std.reporter.warn({
        from = __module_name__,
        subject = "resolve_item",
        message = "Failed to read file for documentation",
        details = { full_path = full_path, error = error },
      })
      return callback(item)
    end

    if not content then
      return callback(item)
    end

    if content == "Binary file" then
      item.documentation = {
        kind = "plaintext",
        value = "Binary file",
      }
    else
      local ext = std.path.extname(item.data.path)
      item.documentation = {
        kind = "markdown",
        value = "```" .. ext .. "\n" .. content .. "```",
      }
    end

    callback(item)
  end)
end

return M
