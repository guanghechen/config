local __module_name__ = "dot.module.explorer.resource.file" ---@type string

---@class dot.module.explorer.resource.file.IProps
---@field public name                   string
---@field public show_hidden            boolean|nil

---@class dot.module.explorer.resource.FileManager : dot.module.explorer.resource.IManager
---@field public name                   string
---@field public fullname               string
---@field protected _show_hidden        boolean
local M = {}
M.__index = M

---@param props                         dot.module.explorer.resource.file.IProps
---@return dot.module.explorer.resource.FileManager
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string
  local show_hidden = props.show_hidden == true ---@type boolean

  local self = setmetatable({}, M)
  self.name = name
  self.fullname = fullname
  self._show_hidden = show_hidden

  return self
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

---@param left                          dot.module.explorer.resource.INode
---@param right                         dot.module.explorer.resource.INode
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
---@return dot.module.explorer.resource.INode|nil
function M:create(uri)
  local filepath = self:__uri_to_filepath__(uri) ---@type string
  if filepath == "" then
    return nil
  end

  local is_directory = uri:sub(-1) == "/" ---@type boolean
  if is_directory then
    local ok, err = pcall(vim.fn.mkdir, filepath, "p")
    if not ok then
      ark.reporter.error({
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
        ark.reporter.error({
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
      ark.reporter.error({
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
    ark.reporter.error({
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
      ark.reporter.error({
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
      ark.reporter.error({
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
        ark.reporter.error({
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
      ark.reporter.error({
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
---@return dot.module.explorer.resource.INode[]
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
  local items = {} ---@type dot.module.explorer.resource.INode[]

  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle) ---@type string|nil, string|nil
    if name == nil then
      break
    end

    if show_hidden or name:sub(1, 1) ~= "." then
      local is_directory = ftype == "directory" ---@type boolean
      local nodetype = is_directory and "D" or "F" ---@type dot.module.explorer.NodeTypeEnum

      ---@type dot.module.explorer.resource.INode
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
---@return dot.module.explorer.resource.INode|nil
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
  local nodetype = is_directory and "D" or "F" ---@type dot.module.explorer.NodeTypeEnum
  local nodename = vim.fn.fnamemodify(filepath, ":t") ---@type string

  if is_directory and uri:sub(-1) ~= "/" then
    uri = uri .. "/"
  end

  ---@type dot.module.explorer.resource.INode
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
    ark.reporter.error({
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
      ark.reporter.error({
        from = self.fullname,
        subject = "move",
        message = string.format("Failed to create target parent directory: %s", target_parent),
        details = { error = err },
      })
      return false
    end
  end

  local move_ok = true ---@type boolean
  dot.lsp.on_rename(source_path, target_path, function()
    local ok, err = pcall(vim.fn.rename, source_path, target_path)
    if not ok then
      ark.reporter.error({
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

  dot.lsp.rename_buf(source_path, target_path)

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
    if ark.env.IS_MAC then
      local result = vim.system({ "trash", "-F", filepath }, { text = true }):wait()
      ok = result.code == 0
      if not ok then
        ark.reporter.error({
          from = self.fullname,
          subject = "remove",
          message = string.format("Failed to move to trash: %s", filepath),
          details = { stderr = result.stderr },
        })
      end
    elseif ark.env.IS_WSL then
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
        ark.reporter.error({
          from = self.fullname,
          subject = "remove",
          message = string.format("Failed to move to trash: %s", filepath),
          details = { stderr = result.stderr },
        })
      end
    elseif ark.env.IS_NIX then
      local result = vim.system({ "gio", "trash", filepath }, { text = true }):wait()
      ok = result.code == 0
      if not ok then
        ark.reporter.error({
          from = self.fullname,
          subject = "remove",
          message = string.format("Failed to move to trash: %s", filepath),
          details = { stderr = result.stderr },
        })
      end
    elseif ark.env.IS_WIN then
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
        ark.reporter.error({
          from = self.fullname,
          subject = "remove",
          message = string.format("Failed to move to trash: %s", filepath),
          details = { stderr = result.stderr },
        })
      end
    else
      ark.reporter.warn({
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
      ark.reporter.error({
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
---@param uri                           string
---@return string
function M:__uri_to_filepath__(uri)
  local prefix = "file://" ---@type string
  if not vim.startswith(uri, prefix) then
    return ""
  end

  local filepath = uri:sub(#prefix + 1) ---@type string
  if filepath:sub(-1) == "/" and #filepath > 1 then
    filepath = filepath:sub(1, -2)
  end

  return filepath
end

---@protected
---@param source_path                   string
---@param target_path                   string
---@return boolean
function M:__copy_file__(source_path, target_path)
  local CHUNK_SIZE = 64 * 1024 ---@type integer

  local stat = vim.uv.fs_stat(source_path) ---@type uv.fs_stat.result|nil
  if stat == nil then
    ark.reporter.error({
      from = self.fullname,
      subject = "copy",
      message = string.format("Failed to stat source file: %s", source_path),
    })
    return false
  end

  local source_fd = vim.uv.fs_open(source_path, "r", 438) ---@type integer|nil
  if source_fd == nil then
    ark.reporter.error({
      from = self.fullname,
      subject = "copy",
      message = string.format("Failed to open source file: %s", source_path),
    })
    return false
  end

  local target_fd = vim.uv.fs_open(target_path, "w", stat.mode) ---@type integer|nil
  if target_fd == nil then
    vim.uv.fs_close(source_fd)
    ark.reporter.error({
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
      ark.reporter.error({
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
---@param source_path                   string
---@param target_path                   string
---@return boolean
function M:__copy_directory__(source_path, target_path)
  local ok, err = pcall(vim.fn.mkdir, target_path, "p")
  if not ok then
    ark.reporter.error({
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

return M
