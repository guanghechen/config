---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.resource.file" ---@type string

local DEBOUNCE_MS = 150 ---@type integer
local MAX_WATCHES = 50 ---@type integer
local OS_SEP = stl.env.PATH_SEP ---@type string

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

---@class era.m.explorer.resource.file.IProps
---@field public name                   string
---@field public show_hidden            ?boolean
---@field public on_change              ?fun()

---@class era.m.explorer.resource.FileManager : era.m.explorer.resource.IManager
---@field public name                   string
---@field public fullname               string
---@field protected _debounce_timer     ?uv.uv_timer_t
---@field protected _disposed           boolean
---@field protected _on_change          ?fun()
---@field protected _pending_change     boolean
---@field protected _show_hidden        boolean
---@field protected _watch_limit_reached boolean
---@field protected _watches            table<string, uv.uv_fs_event_t>
---@field protected _watch_count        integer
local M = {}
M.__index = M

---@param filepath                      string
---@param keep_trailing_slash           boolean|nil
---@return string
local function normalize_filepath(filepath, keep_trailing_slash)
  return stl.os.path.normalize(filepath, keep_trailing_slash)
end

---@param filepath                      string
---@return string
local function to_os_filepath(filepath)
  return stl.os.path.to_os(filepath)
end

---@param filepath                      string
---@return string
local function strip_trailing_slash(filepath)
  if filepath == "/" or filepath:match("^[A-Za-z]:/$") then
    return filepath
  end
  return filepath:gsub("/+$", "")
end

---@param props                         era.m.explorer.resource.file.IProps
---@return era.m.explorer.resource.FileManager
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
  self._watch_limit_reached = false
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
  self._watch_limit_reached = false
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
    if dirpath:sub(-1) == "/" and dirpath ~= "/" and not dirpath:match("^[A-Za-z]:/$") then
      dirpath = dirpath:sub(1, -2)
    end
    wanted[dirpath] = true
  end

  if limit_reached and not self._watch_limit_reached then
    stl.reporter.warn({
      from = self.fullname,
      subject = "sync_watches",
      message = string.format("Watch limit reached (%d directories).", MAX_WATCHES),
    })
  end
  self._watch_limit_reached = limit_reached

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

---@param left                          era.m.explorer.resource.INode
---@param right                         era.m.explorer.resource.INode
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

---@param filepath                           string
---@return era.m.explorer.resource.INode|nil
function M:create(filepath)
  local filepath = self:__filepath_to_filepath__(filepath) ---@type string
  if filepath == "" then
    return nil
  end

  local os_filepath = to_os_filepath(filepath) ---@type string
  local is_directory = filepath:sub(-1) == "/" ---@type boolean
  if is_directory then
    local ok, err = pcall(vim.fn.mkdir, os_filepath, "p")
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
    local os_parent_dir = vim.fn.fnamemodify(os_filepath, ":h") ---@type string
    if vim.fn.isdirectory(os_parent_dir) == 0 then
      local ok, err = pcall(vim.fn.mkdir, os_parent_dir, "p")
      if not ok then
        stl.reporter.error({
          from = self.fullname,
          subject = "create",
          message = string.format("Failed to create parent directory: %s", filepath),
          details = { error = err },
        })
        return nil
      end
    end

    local ok, err = pcall(vim.fn.writefile, {}, os_filepath)
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

  return self:locate(filepath)
end

---@param source_filepath                    string
---@param target_filepath                    string
---@return boolean
function M:copy(source_filepath, target_filepath)
  local source_path = strip_trailing_slash(self:__filepath_to_filepath__(source_filepath)) ---@type string
  local target_path = strip_trailing_slash(self:__filepath_to_filepath__(target_filepath)) ---@type string

  if source_path == "" or target_path == "" then
    return false
  end

  local source_os_path = to_os_filepath(source_path) ---@type string
  local target_os_path = to_os_filepath(target_path) ---@type string

  local source_stat = vim.uv.fs_lstat(source_os_path)
  if source_stat == nil then
    return false
  end

  if source_stat.type == "directory" and yoz.path.is_descendant(source_path, target_path) then
    stl.reporter.error({
      from = self.fullname,
      subject = "copy",
      message = string.format("Cannot copy a directory into itself: %s -> %s", source_path, target_path),
    })
    return false
  end

  if vim.uv.fs_lstat(target_os_path) ~= nil then
    stl.reporter.error({
      from = self.fullname,
      subject = "copy",
      message = string.format("Target already exists: %s", target_path),
    })
    return false
  end

  local target_parent = vim.fn.fnamemodify(target_os_path, ":h") ---@type string
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

  return self:__copy_entry__(source_os_path, target_os_path, source_stat.type)
end

---@param filepath                           string
---@return boolean
function M:insert_if_missing(filepath)
  local filepath = self:__filepath_to_filepath__(filepath) ---@type string
  if filepath == "" then
    return false
  end

  local os_filepath = to_os_filepath(filepath) ---@type string
  local is_directory = filepath:sub(-1) == "/" ---@type boolean
  if is_directory then
    if vim.fn.isdirectory(os_filepath) == 1 then
      return true
    end
    local ok, err = pcall(vim.fn.mkdir, os_filepath, "p")
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
    if vim.fn.filereadable(os_filepath) == 1 then
      return true
    end

    local parent_dir = vim.fn.fnamemodify(os_filepath, ":h") ---@type string
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

    local ok, err = pcall(vim.fn.writefile, {}, os_filepath)
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

---@param filepath                           string
---@return era.m.explorer.resource.INode[]
function M:load(filepath)
  local filepath = self:__filepath_to_filepath__(filepath) ---@type string
  if filepath == "" then
    return {}
  end

  local os_filepath = to_os_filepath(filepath) ---@type string
  local stat = vim.uv.fs_stat(os_filepath)
  if stat == nil or stat.type ~= "directory" then
    return {}
  end

  local handle = vim.uv.fs_scandir(os_filepath) ---@type userdata|nil
  if handle == nil then
    return {}
  end

  local show_hidden = self._show_hidden ---@type boolean
  local items = {} ---@type era.m.explorer.resource.INode[]

  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle) ---@type string|nil, string|nil
    if name == nil then
      break
    end

    if show_hidden or name:sub(1, 1) ~= "." then
      local is_directory ---@type boolean
      if ftype == "directory" then
        is_directory = true
      elseif ftype == "file" then
        is_directory = false
      else
        -- Symlinks report as "link" (and some filesystems report "unknown") from scandir,
        -- which cannot reveal the target type. Follow the link for explorer interaction only;
        -- side-effecting operations use lstat so they still act on the link itself. Dangling
        -- links fall back to a file leaf.
        local target_stat = vim.uv.fs_stat(to_os_filepath(filepath .. name)) ---@type uv.fs_stat.result|nil
        is_directory = target_stat ~= nil and target_stat.type == "directory"
      end
      local nodetype = is_directory and "D" or "F" ---@type era.m.explorer.NodeTypeEnum

      ---@type era.m.explorer.resource.INode
      local item = {
        filepath = filepath .. name .. (is_directory and "/" or ""),
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

---@param filepath                           string
---@return era.m.explorer.resource.INode|nil
function M:locate(filepath)
  local filepath = self:__filepath_to_filepath__(filepath) ---@type string
  if filepath == "" then
    return nil
  end

  local os_filepath = to_os_filepath(filepath) ---@type string
  local stat = vim.uv.fs_stat(os_filepath)
  if stat == nil then
    return nil
  end

  local is_directory = stat.type == "directory" ---@type boolean
  local nodetype = is_directory and "D" or "F" ---@type era.m.explorer.NodeTypeEnum
  local without_slash = filepath:sub(-1) == "/" and filepath:sub(1, -2) or filepath ---@type string
  local nodename = without_slash:match("([^/]+)$") or "" ---@type string

  if is_directory and filepath:sub(-1) ~= "/" then
    filepath = filepath .. "/"
  end

  ---@type era.m.explorer.resource.INode
  return {
    filepath = filepath,
    nodetype = nodetype,
    nodename = nodename,
  }
end

---@param source_filepath                    string
---@param target_filepath                    string
---@return boolean
function M:move(source_filepath, target_filepath)
  local source_path = strip_trailing_slash(self:__filepath_to_filepath__(source_filepath)) ---@type string
  local target_path = strip_trailing_slash(self:__filepath_to_filepath__(target_filepath)) ---@type string

  if source_path == "" or target_path == "" then
    return false
  end

  local source_os_path = to_os_filepath(source_path) ---@type string
  local target_os_path = to_os_filepath(target_path) ---@type string

  if vim.uv.fs_lstat(target_os_path) ~= nil then
    stl.reporter.error({
      from = self.fullname,
      subject = "move",
      message = string.format("Target already exists: %s", target_path),
    })
    return false
  end

  local target_parent = vim.fn.fnamemodify(target_os_path, ":h") ---@type string
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

  local renamed = era.m.lsp.event.on_rename(source_os_path, target_os_path, function()
    local ok, result = pcall(vim.fn.rename, source_os_path, target_os_path)
    if not ok or result ~= 0 then
      stl.reporter.error({
        from = self.fullname,
        subject = "move",
        message = string.format("Failed to move: %s -> %s", source_path, target_path),
        details = {
          error = not ok and result or nil,
          code = ok and result or nil,
        },
      })
      return false
    end
    return true
  end)

  if not renamed then
    return false
  end

  era.m.lsp.event.rename_buf(source_os_path, target_os_path)

  return true
end

---@param filepath                           string
---@param on_removed                    fun(): nil
---@return boolean
function M:remove(filepath, on_removed)
  local filepath = strip_trailing_slash(self:__filepath_to_filepath__(filepath)) ---@type string
  if filepath == "" then
    return false
  end

  local os_filepath = to_os_filepath(filepath) ---@type string
  local stat = vim.uv.fs_lstat(os_filepath)
  if stat == nil then
    return false
  end

  local use_trash = dot.context.explorer.trash:snapshot() ---@type boolean
  local ok = false ---@type boolean
  local is_directory = stat.type == "directory" ---@type boolean
  if use_trash and stat.type == "link" and (stl.env.IS_WIN or stl.env.IS_WSL) then
    local target_stat = vim.uv.fs_stat(os_filepath) ---@type uv.fs_stat.result|nil
    is_directory = target_stat ~= nil and target_stat.type == "directory"
  end

  if use_trash then
    -- os_filepath has no trailing slash, so native trash tools operate on the link itself.
    if stl.env.IS_OSX then
      local result = vim.system({ "trash", "-F", os_filepath }, { text = true }):wait()
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
      local win_path = vim.fn.system({ "wslpath", "-w", os_filepath }):gsub("\n", "")
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
      local result = vim.system({ "gio", "trash", os_filepath }, { text = true }):wait()
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
          os_filepath:gsub("'", "''")
        )
      else
        ps_script = string.format(
          [[Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('%s', 'OnlyErrorDialogs', 'SendToRecycleBin')]],
          os_filepath:gsub("'", "''")
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
    if stat.type == "link" then
      ok, err = vim.uv.fs_unlink(os_filepath)
    elseif stat.type == "directory" then
      local call_ok, result = pcall(vim.fn.delete, os_filepath, "rf")
      ok = call_ok and result == 0
      err = result
    else
      local call_ok, result = pcall(vim.fn.delete, os_filepath)
      ok = call_ok and result == 0
      err = result
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
---@param source_type                   ?string
---@return boolean
function M:__copy_entry__(source_path, target_path, source_type)
  if source_type == nil or source_type == "unknown" then
    local source_stat = vim.uv.fs_lstat(source_path) ---@type uv.fs_stat.result|nil
    if source_stat == nil then
      return false
    end
    source_type = source_stat.type
  end

  if source_type == "link" then
    return self:__copy_link__(source_path, target_path)
  elseif source_type == "directory" then
    return self:__copy_directory__(source_path, target_path)
  end
  return self:__copy_file__(source_path, target_path)
end

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

  local source_prefix = source_path:sub(-1) == OS_SEP and source_path or (source_path .. OS_SEP) ---@type string
  local target_prefix = target_path:sub(-1) == OS_SEP and target_path or (target_path .. OS_SEP) ---@type string

  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle) ---@type string|nil, string|nil
    if name == nil then
      break
    end

    local child_source = source_prefix .. name ---@type string
    local child_target = target_prefix .. name ---@type string

    if not self:__copy_entry__(child_source, child_target, ftype) then
      return false
    end
  end

  return true
end

---@protected
---@param source_path                   string
---@param target_path                   string
---@return boolean
function M:__copy_link__(source_path, target_path)
  local link_target, read_err = vim.uv.fs_readlink(source_path)
  if link_target == nil then
    stl.reporter.error({
      from = self.fullname,
      subject = "copy",
      message = string.format("Failed to read symbolic link: %s", source_path),
      details = { error = read_err },
    })
    return false
  end

  local flags = nil ---@type uv.fs_symlink.flags|nil
  if stl.env.IS_WIN then
    local target_stat = vim.uv.fs_stat(source_path) ---@type uv.fs_stat.result|nil
    flags = { dir = target_stat ~= nil and target_stat.type == "directory", junction = false }
  end
  local ok, err = vim.uv.fs_symlink(link_target, target_path, flags)
  if not ok then
    stl.reporter.error({
      from = self.fullname,
      subject = "copy",
      message = string.format("Failed to copy symbolic link: %s -> %s", source_path, target_path),
      details = { error = err },
    })
    return false
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

  local os_dirpath = to_os_filepath(dirpath) ---@type string
  local ok, err = handle:start(os_dirpath, {}, function(watch_err, filename)
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
  self._debounce_timer:start(
    DEBOUNCE_MS,
    0,
    vim.schedule_wrap(function()
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
    end)
  )
end

---@protected
---@param filepath                           string
---@return string
function M:__filepath_to_filepath__(filepath)
  if type(filepath) ~= "string" then
    return ""
  end

  if #filepath == 0 then
    return ""
  end

  local keep_trailing_slash = filepath:sub(-1) == "/" ---@type boolean
  return normalize_filepath(filepath, keep_trailing_slash)
end

return M
