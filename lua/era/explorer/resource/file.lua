local __module_name__ = "era.explorer.resource.file" ---@type string

local DEBOUNCE_MS = 150 ---@type integer
local MAX_WATCHES = 50 ---@type integer

local WATCH_IGNORE_PATTERNS = {
  "^%.git$",
  "^%.hg$",
  "^%.svn$",
  "^%.DS_Store$",
  "^%.Spotlight%-",
  "^%.Trashes$",
  "^%.fseventsd$",
  "^__pycache__$",
  "^node_modules$",
  "^%.cache$",
  "^%.vscode%-server$",
} ---@type string[]

---@class era.explorer.resource.file.IProps
---@field public name                   string
---@field public show_hidden            boolean|nil
---@field public on_change              fun()|nil

---@class era.explorer.resource.FileManager : era.explorer.resource.IManager
---@field public name                   string
---@field public fullname               string
---@field protected _debounce_timer     uv.uv_timer_t|nil
---@field protected _disposed           boolean
---@field protected _on_change          fun()|nil
---@field protected _pending_change     boolean
---@field protected _show_hidden        boolean
---@field protected _watches            table<string, uv.uv_fs_event_t>
---@field protected _watch_count        integer
local M = {}
M.__index = M

---@param props                         era.explorer.resource.file.IProps
---@return era.explorer.resource.FileManager
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string
  local show_hidden = props.show_hidden == true ---@type boolean

  local self = setmetatable({}, M)
  self.name = name
  self.fullname = fullname
  self._debounce_timer = nil
  self._disposed = false
  self._on_change = props.on_change
  self._pending_change = false
  self._show_hidden = show_hidden
  self._watches = {}
  self._watch_count = 0

  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  self:__stop_all_watches__()

  if self._debounce_timer and not self._debounce_timer:is_closing() then
    self._debounce_timer:stop()
    self._debounce_timer:close()
    self._debounce_timer = nil
  end
end

---@return nil
function M:pause_watch()
  if self._disposed then
    return
  end
  self:__stop_all_watches__()
end

---@param expanded_dirs                 string[]
---@return nil
function M:sync_watches(expanded_dirs)
  if self._disposed then
    return
  end

  local wanted = {} ---@type table<string, boolean>
  local limit_reached = false ---@type boolean

  for i, dirpath in ipairs(expanded_dirs) do
    if i > MAX_WATCHES then
      limit_reached = true
      break
    end
    if dirpath:sub(-1) == "/" then
      dirpath = dirpath:sub(1, -2)
    end
    wanted[dirpath] = true
  end

  if limit_reached then
    stl.reporter.warn({
      from = self.fullname,
      subject = "sync_watches",
      message = string.format("Watch limit reached (%d directories).", MAX_WATCHES),
    })
  end

  for path in pairs(wanted) do
    if not self._watches[path] then
      self:__start_watch__(path)
    end
  end

  for path in pairs(self._watches) do
    if not wanted[path] then
      self:__stop_watch__(path)
    end
  end
end

---@param show_hidden                   boolean
---@return nil
function M:set_show_hidden(show_hidden)
  self._show_hidden = show_hidden
end

---@return boolean
function M:get_show_hidden()
  return self._show_hidden
end

---@param left                          era.explorer.resource.INode
---@param right                         era.explorer.resource.INode
---@return integer
function M.compare(left, right)
  if left.nodetype ~= right.nodetype then
    return left.nodetype == "D" and -1 or 1
  end

  local left_name = left.nodename:lower() ---@type string
  local right_name = right.nodename:lower() ---@type string
  if left_name < right_name then
    return -1
  elseif left_name > right_name then
    return 1
  end
  return 0
end

---@param uri                           string
---@return era.explorer.resource.INode|nil
function M:create(uri)
  local filepath = self:__uri_to_filepath__(uri) ---@type string
  if filepath == "" then
    return nil
  end

  local is_directory = uri:sub(-1) == "/" ---@type boolean
  if is_directory then
    local ok, err = pcall(vim.fn.mkdir, filepath, "p")
    if not ok then
      stl.reporter.error({
        from = self.fullname,
        subject = "create",
        message = string.format("Failed to create directory: %s", filepath),
        details = { error = err },
      })
      return nil
    end
  else
    local parent_dir = vim.fn.fnamemodify(filepath, ":h") ---@type string
    if vim.fn.isdirectory(parent_dir) == 0 then
      local ok, err = pcall(vim.fn.mkdir, parent_dir, "p")
      if not ok then
        stl.reporter.error({
          from = self.fullname,
          subject = "create",
          message = string.format("Failed to create parent directory: %s", parent_dir),
          details = { error = err },
        })
        return nil
      end
    end

    local ok, err = pcall(vim.fn.writefile, {}, filepath)
    if not ok then
      stl.reporter.error({
        from = self.fullname,
        subject = "create",
        message = string.format("Failed to create file: %s", filepath),
        details = { error = err },
      })
      return nil
    end
  end

  return self:locate(uri)
end

---@param source_uri                    string
---@param target_uri                    string
---@return boolean
function M:copy(source_uri, target_uri)
  local source_path = self:__uri_to_filepath__(source_uri) ---@type string
  local target_path = self:__uri_to_filepath__(target_uri) ---@type string

  if source_path == "" or target_path == "" then
    return false
  end

  if vim.fn.filereadable(target_path) == 1 or vim.fn.isdirectory(target_path) == 1 then
    stl.reporter.error({
      from = self.fullname,
      subject = "copy",
      message = string.format("Target already exists: %s", target_path),
    })
    return false
  end

  local target_parent = vim.fn.fnamemodify(target_path, ":h") ---@type string
  if vim.fn.isdirectory(target_parent) == 0 then
    local ok, err = pcall(vim.fn.mkdir, target_parent, "p")
    if not ok then
      stl.reporter.error({
        from = self.fullname,
        subject = "copy",
        message = string.format("Failed to create target parent directory: %s", target_parent),
        details = { error = err },
      })
      return false
    end
  end

  local source_stat = vim.uv.fs_stat(source_path)
  if source_stat == nil then
    return false
  end

  if source_stat.type == "directory" then
    return self:__copy_directory__(source_path, target_path)
  else
    return self:__copy_file__(source_path, target_path)
  end
end

---@param uri                           string
---@return boolean
function M:insert_if_missing(uri)
  local filepath = self:__uri_to_filepath__(uri) ---@type string
  if filepath == "" then
    return false
  end

  local is_directory = uri:sub(-1) == "/" ---@type boolean
  if is_directory then
    if vim.fn.isdirectory(filepath) == 1 then
      return true
    end
    local ok, err = pcall(vim.fn.mkdir, filepath, "p")
    if not ok then
      stl.reporter.error({
        from = self.fullname,
        subject = "insert_if_missing",
        message = string.format("Failed to create directory: %s", filepath),
        details = { error = err },
      })
      return false
    end
    return true
  else
    if vim.fn.filereadable(filepath) == 1 then
      return true
    end

    local parent_dir = vim.fn.fnamemodify(filepath, ":h") ---@type string
    if vim.fn.isdirectory(parent_dir) == 0 then
      local ok, err = pcall(vim.fn.mkdir, parent_dir, "p")
      if not ok then
        stl.reporter.error({
          from = self.fullname,
          subject = "insert_if_missing",
          message = string.format("Failed to create parent directory: %s", parent_dir),
          details = { error = err },
        })
        return false
      end
    end

    local ok, err = pcall(vim.fn.writefile, {}, filepath)
    if not ok then
      stl.reporter.error({
        from = self.fullname,
        subject = "insert_if_missing",
        message = string.format("Failed to create file: %s", filepath),
        details = { error = err },
      })
      return false
    end
    return true
  end
end

---@param uri                           string
---@return era.explorer.resource.INode[]
function M:load(uri)
  local filepath = self:__uri_to_filepath__(uri) ---@type string
  if filepath == "" then
    return {}
  end

  local stat = vim.uv.fs_stat(filepath)
  if stat == nil or stat.type ~= "directory" then
    return {}
  end

  local handle = vim.uv.fs_scandir(filepath) ---@type userdata|nil
  if handle == nil then
    return {}
  end

  local show_hidden = self._show_hidden ---@type boolean
  local items = {} ---@type era.explorer.resource.INode[]

  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle) ---@type string|nil, string|nil
    if name == nil then
      break
    end

    if show_hidden or name:sub(1, 1) ~= "." then
      local is_directory = ftype == "directory" ---@type boolean
      local nodetype = is_directory and "D" or "F" ---@type era.explorer.NodeTypeEnum

      ---@type era.explorer.resource.INode
      local item = {
        uri = uri .. name .. (is_directory and "/" or ""),
        nodetype = nodetype,
        nodename = name,
      }
      items[#items + 1] = item
    end
  end

  table.sort(items, function(a, b)
    return M.compare(a, b) < 0
  end)

  return items
end

---@param uri                           string
---@return era.explorer.resource.INode|nil
function M:locate(uri)
  local filepath = self:__uri_to_filepath__(uri) ---@type string
  if filepath == "" then
    return nil
  end

  local stat = vim.uv.fs_stat(filepath)
  if stat == nil then
    return nil
  end

  local is_directory = stat.type == "directory" ---@type boolean
  local nodetype = is_directory and "D" or "F" ---@type era.explorer.NodeTypeEnum
  local nodename = vim.fn.fnamemodify(filepath, ":t") ---@type string

  if is_directory and uri:sub(-1) ~= "/" then
    uri = uri .. "/"
  end

  ---@type era.explorer.resource.INode
  return {
    uri = uri,
    nodetype = nodetype,
    nodename = nodename,
  }
end

---@param source_uri                    string
---@param target_uri                    string
---@return boolean
function M:move(source_uri, target_uri)
  local source_path = self:__uri_to_filepath__(source_uri) ---@type string
  local target_path = self:__uri_to_filepath__(target_uri) ---@type string

  if source_path == "" or target_path == "" then
    return false
  end

  if vim.fn.filereadable(target_path) == 1 or vim.fn.isdirectory(target_path) == 1 then
    stl.reporter.error({
      from = self.fullname,
      subject = "move",
      message = string.format("Target already exists: %s", target_path),
    })
    return false
  end

  local target_parent = vim.fn.fnamemodify(target_path, ":h") ---@type string
  if vim.fn.isdirectory(target_parent) == 0 then
    local ok, err = pcall(vim.fn.mkdir, target_parent, "p")
    if not ok then
      stl.reporter.error({
        from = self.fullname,
        subject = "move",
        message = string.format("Failed to create target parent directory: %s", target_parent),
        details = { error = err },
      })
      return false
    end
  end

  local move_ok = true ---@type boolean
  era.lsp.event.on_rename(source_path, target_path, function()
    local ok, err = pcall(vim.fn.rename, source_path, target_path)
    if not ok then
      stl.reporter.error({
        from = self.fullname,
        subject = "move",
        message = string.format("Failed to move: %s -> %s", source_path, target_path),
        details = { error = err },
      })
      move_ok = false
    end
  end)

  if not move_ok then
    return false
  end

  era.lsp.event.rename_buf(source_path, target_path)

  return true
end

---@param uri                           string
---@param on_removed                    fun(): nil
---@return boolean
function M:remove(uri, on_removed)
  local filepath = self:__uri_to_filepath__(uri) ---@type string
  if filepath == "" then
    return false
  end

  local stat = vim.uv.fs_stat(filepath)
  if stat == nil then
    return false
  end

  local use_trash = dot.context.explorer.trash:snapshot() ---@type boolean
  local ok = false ---@type boolean
  local is_directory = stat.type == "directory" ---@type boolean

  if use_trash then
    if stl.env.IS_MAC then
      local result = vim.system({ "trash", "-F", filepath }, { text = true }):wait()
      ok = result.code == 0
      if not ok then
        stl.reporter.error({
          from = self.fullname,
          subject = "remove",
          message = string.format("Failed to move to trash: %s", filepath),
          details = { stderr = result.stderr },
        })
      end
    elseif stl.env.IS_WSL then
      local win_path = vim.fn.system({ "wslpath", "-w", filepath }):gsub("\n", "")
      local ps_script ---@type string
      if is_directory then
        ps_script = string.format(
          [[Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory('%s', 'OnlyErrorDialogs', 'SendToRecycleBin')]],
          win_path:gsub("'", "''")
        )
      else
        ps_script = string.format(
          [[Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('%s', 'OnlyErrorDialogs', 'SendToRecycleBin')]],
          win_path:gsub("'", "''")
        )
      end
      local result = vim.system({ "powershell.exe", "-NoProfile", "-Command", ps_script }, { text = true }):wait()
      ok = result.code == 0
      if not ok then
        stl.reporter.error({
          from = self.fullname,
          subject = "remove",
          message = string.format("Failed to move to trash: %s", filepath),
          details = { stderr = result.stderr },
        })
      end
    elseif stl.env.IS_NIX then
      local result = vim.system({ "gio", "trash", filepath }, { text = true }):wait()
      ok = result.code == 0
      if not ok then
        stl.reporter.error({
          from = self.fullname,
          subject = "remove",
          message = string.format("Failed to move to trash: %s", filepath),
          details = { stderr = result.stderr },
        })
      end
    elseif stl.env.IS_WIN then
      local ps_script ---@type string
      if is_directory then
        ps_script = string.format(
          [[Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory('%s', 'OnlyErrorDialogs', 'SendToRecycleBin')]],
          filepath:gsub("'", "''")
        )
      else
        ps_script = string.format(
          [[Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('%s', 'OnlyErrorDialogs', 'SendToRecycleBin')]],
          filepath:gsub("'", "''")
        )
      end
      local result = vim.system({ "powershell", "-NoProfile", "-Command", ps_script }, { text = true }):wait()
      ok = result.code == 0
      if not ok then
        stl.reporter.error({
          from = self.fullname,
          subject = "remove",
          message = string.format("Failed to move to trash: %s", filepath),
          details = { stderr = result.stderr },
        })
      end
    else
      stl.reporter.warn({
        from = self.fullname,
        subject = "remove",
        message = "Trash is not supported on this platform, falling back to permanent delete",
      })
      use_trash = false
    end
  end

  if not use_trash then
    local err ---@type any
    if is_directory then
      ok, err = pcall(vim.fn.delete, filepath, "rf")
    else
      ok, err = pcall(vim.fn.delete, filepath)
    end
    if not ok then
      stl.reporter.error({
        from = self.fullname,
        subject = "remove",
        message = string.format("Failed to remove: %s", filepath),
        details = { error = err },
      })
    end
  end

  if not ok then
    return false
  end

  on_removed()
  return true
end

----------------------------------------------------------------------------------------------------

---@protected
---@param source_path                   string
---@param target_path                   string
---@return boolean
function M:__copy_directory__(source_path, target_path)
  local ok, err = pcall(vim.fn.mkdir, target_path, "p")
  if not ok then
    stl.reporter.error({
      from = self.fullname,
      subject = "copy",
      message = string.format("Failed to create target directory: %s", target_path),
      details = { error = err },
    })
    return false
  end

  local handle = vim.uv.fs_scandir(source_path) ---@type userdata|nil
  if handle == nil then
    return true
  end

  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle) ---@type string|nil, string|nil
    if name == nil then
      break
    end

    local child_source = source_path .. "/" .. name ---@type string
    local child_target = target_path .. "/" .. name ---@type string

    if ftype == "directory" then
      if not self:__copy_directory__(child_source, child_target) then
        return false
      end
    else
      if not self:__copy_file__(child_source, child_target) then
        return false
      end
    end
  end

  return true
end

---@protected
---@param source_path                   string
---@param target_path                   string
---@return boolean
function M:__copy_file__(source_path, target_path)
  local CHUNK_SIZE = 64 * 1024 ---@type integer

  local stat = vim.uv.fs_stat(source_path) ---@type uv.fs_stat.result|nil
  if stat == nil then
    stl.reporter.error({
      from = self.fullname,
      subject = "copy",
      message = string.format("Failed to stat source file: %s", source_path),
    })
    return false
  end

  local source_fd = vim.uv.fs_open(source_path, "r", 438) ---@type integer|nil
  if source_fd == nil then
    stl.reporter.error({
      from = self.fullname,
      subject = "copy",
      message = string.format("Failed to open source file: %s", source_path),
    })
    return false
  end

  local target_fd = vim.uv.fs_open(target_path, "w", stat.mode) ---@type integer|nil
  if target_fd == nil then
    vim.uv.fs_close(source_fd)
    stl.reporter.error({
      from = self.fullname,
      subject = "copy",
      message = string.format("Failed to create target file: %s", target_path),
    })
    return false
  end

  local offset = 0 ---@type integer
  local file_size = stat.size ---@type integer
  local success = true ---@type boolean

  while offset < file_size do
    local chunk = vim.uv.fs_read(source_fd, CHUNK_SIZE, offset) ---@type string|nil
    if chunk == nil or #chunk == 0 then
      break
    end
    local written = vim.uv.fs_write(target_fd, chunk, offset) ---@type integer|nil
    if written == nil or written ~= #chunk then
      success = false
      stl.reporter.error({
        from = self.fullname,
        subject = "copy",
        message = string.format("Failed to write to target file: %s", target_path),
      })
      break
    end
    offset = offset + #chunk
  end

  vim.uv.fs_close(source_fd)
  vim.uv.fs_close(target_fd)

  return success
end

---@protected
---@param dirpath                       string
---@return nil
function M:__start_watch__(dirpath)
  if self._watches[dirpath] then
    return
  end

  if self._watch_count >= MAX_WATCHES then
    return
  end

  local handle = vim.uv.new_fs_event() ---@type uv.uv_fs_event_t|nil
  if not handle then
    return
  end

  local ok, err = handle:start(dirpath, {}, function(watch_err, filename)
    if watch_err then
      return
    end

    if filename then
      if filename:match("%.swp$") or filename:match("%.tmp$") or filename:match("~$") or filename:match("^4913$") then
        return
      end
      for _, pattern in ipairs(WATCH_IGNORE_PATTERNS) do
        if filename:match(pattern) then
          return
        end
      end
    end

    self:__trigger_change__()
  end)

  if not ok then
    stl.reporter.warn({
      from = self.fullname,
      subject = "watch",
      message = string.format("Failed to watch: %s", dirpath),
      details = { error = err },
    })
    if not handle:is_closing() then
      handle:close()
    end
    return
  end

  self._watches[dirpath] = handle
  self._watch_count = self._watch_count + 1
end

---@protected
---@return nil
function M:__stop_all_watches__()
  for path in pairs(self._watches) do
    self:__stop_watch__(path)
  end
end

---@protected
---@param dirpath                       string
---@return nil
function M:__stop_watch__(dirpath)
  local handle = self._watches[dirpath] ---@type uv.uv_fs_event_t|nil
  if not handle then
    return
  end

  if not handle:is_closing() then
    handle:stop()
    handle:close()
  end

  self._watches[dirpath] = nil
  self._watch_count = self._watch_count - 1
end

---@protected
---@return nil
function M:__trigger_change__()
  self._pending_change = true

  if not self._debounce_timer then
    self._debounce_timer = vim.uv.new_timer()
  end

  if not self._debounce_timer then
    return
  end

  self._debounce_timer:stop()
  self._debounce_timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    if self._disposed then
      return
    end

    if not self._pending_change then
      return
    end

    self._pending_change = false

    if self._on_change then
      self._on_change()
    end
  end))
end

---@protected
---@param uri                           string
---@return string
function M:__uri_to_filepath__(uri)
  return yoz.uri.to_filepath(uri) or ""
end

return M
