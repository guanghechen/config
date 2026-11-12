---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.fs" ---@type string

---@class stl.t.IReadFileParams
---@field public filepath               string
---@field public silent                 ?boolean

---@class stl.t.IReadFileAsBase64Params
---@field public filepath               string
---@field public silent                 ?boolean

---@class stl.t.IReadFileAsLinesParams
---@field public filepath               string
---@field public max_lines              ?integer
---@field public silent                 ?boolean

---@class stl.t.IReadJsonParams
---@field public filepath               string
---@field public silent_on_bad_path     ?boolean
---@field public silent_on_bad_json     ?boolean

---@class stl.fs
local M = {}

---@param filepath                      string
---@param err                           any
---@param unwatch                       fun():nil
local function default_watch_on_error(filepath, err, unwatch)
  stl.reporter.error({
    from = __module_name__,
    subject = "watch_file",
    message = "Failed to watch file.",
    details = { filepath = filepath, err = err },
  })
  unwatch()
end

---@param filepath_source               string
---@param filepath_target               string
---@param force                         ?boolean
---@return boolean                      Whether the file was copied
function M.copy_file(filepath_source, filepath_target, force)
  force = force or false

  -- Check if target already exists and confirm overwrite if not forced
  if not force and yoz.path.is_exist(filepath_target) then
    local choice = vim.fn.confirm(string.format("File already exists: %s\nOverwrite?", filepath_target), "&Yes\n&No", 2)
    if choice ~= 1 then
      return false
    end
  end

  local fin, err_open = io.open(filepath_source, "rb")
  if not fin then
    stl.reporter.error({
      from = __module_name__,
      subject = "copy_file",
      message = "Failed to open source file.",
      details = { filepath_source = filepath_source, error = err_open },
    })
    return false
  end

  local content, err_read = fin:read("*all")
  fin:close()

  if not content then
    stl.reporter.error({
      from = __module_name__,
      subject = "copy_file",
      message = "Failed to read source file.",
      details = { filepath_source = filepath_source, error = err_read },
    })
    return false
  end

  stl.env.mkdirs(filepath_target, false)

  local fout, err_create = io.open(filepath_target, "wb")
  if not fout then
    stl.reporter.error({
      from = __module_name__,
      subject = "copy_file",
      message = "Failed to create target file.",
      details = { filepath_target = filepath_target, error = err_create },
    })
    return false
  end

  local ok, err_write = fout:write(content)
  fout:close()

  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "copy_file",
      message = "Failed to write to target file.",
      details = { filepath_target = filepath_target, error = err_write },
    })
    return false
  end

  return true
end

---@param dirpath_source                string
---@param dirpath_target                string
---@param force                         ?boolean
---@return boolean
function M.copy_directory(dirpath_source, dirpath_target, force)
  force = force or false

  -- Check if target already exists and confirm overwrite if not forced
  if not force and yoz.path.is_exist(dirpath_target) then
    local choice =
      vim.fn.confirm(string.format("Directory already exists: %s\nOverwrite contents?", dirpath_target), "&Yes\n&No", 2)
    if choice ~= 1 then
      return false
    end
  end

  stl.env.mkdirs(dirpath_target, true)

  local handle = vim.uv.fs_scandir(dirpath_source)
  if not handle then
    stl.reporter.error({
      from = __module_name__,
      subject = "copy_directory",
      message = "Failed to open source directory.",
      details = { dir_source = dirpath_source },
    })
    return false
  end

  local success = true
  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end

    local source_path = dirpath_source .. stl.env.PATH_SEP .. name
    local target_path = dirpath_target .. stl.env.PATH_SEP .. name

    if type == "directory" then
      success = M.copy_directory(source_path, target_path, force) and success
    else
      local copied = M.copy_file(source_path, target_path, force)
      if not copied then
        success = false
      end
    end
  end

  return success
end

---@param params                        stl.t.IReadFileParams
---@return string|nil
function M.read_file(params)
  local filepath = params.filepath ---@type string
  local silent = not not params.silent ---@type boolean
  local file = io.open(filepath, "rb") -- rb: read in binary mode
  if not file then
    if not silent then
      stl.reporter.error({
        from = __module_name__,
        subject = "read_file",
        message = "Failed to open filepath.",
        details = { filepath = filepath },
      })
    end
    return nil
  end

  local content = file:read("*a") -- Read the entire content of the file
  file:close()
  return content -- Assuming the content is UTF-8 encoded, it can now be used as a string
end

---@param params                        stl.t.IReadFileAsBase64Params
---@return string|nil
function M.read_file_as_base64(params)
  local filepath = params.filepath ---@type string
  local silent = not not params.silent ---@type boolean
  local file = io.open(filepath, "rb")
  if not file then
    if not silent then
      stl.reporter.error({
        from = __module_name__,
        subject = "read_file_as_base64",
        message = "Failed to open filepath.",
        details = { filepath = filepath },
      })
    end
    return nil
  end

  local content = file:read("*a") -- Read the entire content of the file
  file:close()
  return vim.base64.encode(content)
end

---@param params                        stl.t.IReadFileAsLinesParams
---@return string[]
function M.read_file_as_lines(params)
  local filepath = params.filepath ---@type string
  local silent = not not params.silent ---@type boolean
  -- Text mode on Windows would translate CRLF and stop at Ctrl-Z; binary mode reads the same bytes everywhere.
  local file = io.open(filepath, "rb")
  if not file then
    if not silent then
      stl.reporter.error({
        from = __module_name__,
        subject = "read_file_as_lines",
        message = "Failed to open filepath.",
        details = { filepath = filepath },
      })
    end
    return {}
  end

  local lines = {} ---@type string[]
  local max_lines = params.max_lines or math.huge ---@type integer
  for line in file:lines() do
    if #lines >= max_lines then
      break
    end
    -- Lines end at "\n"; like `readfile()`, drop the "\r" of a CRLF line break.
    if line:byte(-1) == 13 then
      line = line:sub(1, -2)
    end
    -- As in a buffer Neovim loads, and in the text file search matches, the text starts after a leading UTF-8 byte
    -- order mark; a mark further on is text.
    if #lines == 0 and line:sub(1, 3) == "\239\187\191" then
      line = line:sub(4)
    end
    table.insert(lines, line)
  end

  file:close()
  return lines
end

---@param params                        stl.t.IReadJsonParams
---@return any|nil
function M.read_json(params)
  local filepath = params.filepath ---@type string
  local silent_on_bad_json = not not params.silent_on_bad_json ---@type boolean
  local silent_on_bad_path = not not params.silent_on_bad_path ---@type boolean
  local ok_to_load_json, json_text = pcall(M.read_file, { filepath = filepath, silent = silent_on_bad_path })
  if not ok_to_load_json then
    return
  end

  if json_text == nil then
    return nil
  end

  local ok_to_decode_json, data = pcall(vim.json.decode, json_text, {
    luanil = {
      object = true,
      array = true,
    },
  })
  if not ok_to_decode_json then
    if not silent_on_bad_json then
      stl.reporter.warn({
        from = __module_name__,
        subject = "read_json",
        message = "Failed to decode json",
        details = { filepath = filepath, json_text = json_text },
      })
    end
    return nil
  end

  return data
end

---@class stl.t.IWatchFileOptions
---@field public filepath               string
---@field public on_event               fun(filepath:string, events: any, unwatch:fun():nil):nil
---@field public on_error               ?fun(filepath:string, err: any, unwatch:fun():nil):nil

---Watches the directory of the file, since a watch on the file itself stays on the old file once a writer renames
---another over it, as `write_file` does. Such a replacement reports `rename` rather than `change`.
---@param opts                          stl.t.IWatchFileOptions
---@return fun():nil
function M.watch_file(opts)
  local filepath = opts.filepath
  local on_event = opts.on_event
  local on_error = opts.on_error or default_watch_on_error
  local os_filepath = yoz.canonical_path.to_os_path(filepath) ---@type string
  local basename = yoz.path.basename(os_filepath) ---@type string

  local handle = vim.uv.new_fs_event()
  local flags = {
    watch_entry = false,
    stat = false,
    recursive = false,
  }

  local unwatch = function()
    if handle ~= nil then
      vim.uv.fs_event_stop(handle)
      if not handle:is_closing() then
        handle:close()
      end
      handle = nil
    end
  end

  local callback = function(err, filename, events)
    if err then
      on_error(filepath, err, unwatch)
    elseif filename == nil or filename == basename then
      on_event(filepath, events, unwatch)
    end
  end

  ---attacher handler
  if handle ~= nil then
    vim.uv.fs_event_start(handle, yoz.path.dirname(os_filepath, false, stl.env.PATH_SEP), flags, callback)
  end
  return unwatch
end

local tmp_seq = 0 ---@type integer

---Writes to a sibling temporary file renamed over the target, so a failed write keeps the previous content and
---no reader sees a partial file. A symlink keeps pointing at the file it links to.
---@param filepath                      string
---@param content                       string
---@return boolean                      Whether the content was written
---@return string|nil                   Why it was not
function M.write_file(filepath, content)
  -- A missing directory fails the open below, which reports it.
  pcall(stl.env.mkdirs, filepath, false)

  local os_filepath = yoz.canonical_path.to_os_path(filepath) ---@type string
  -- Renaming over a symlink would replace the link.
  local target = vim.uv.fs_realpath(os_filepath) or os_filepath ---@type string
  local stat = vim.uv.fs_stat(target)
  tmp_seq = tmp_seq + 1
  local tmppath = string.format("%s.%d-%d.tmp", target, vim.uv.os_getpid(), tmp_seq) ---@type string

  local err = nil ---@type string|nil
  -- A rename ignores the permissions of the file it replaces.
  if stat ~= nil and not vim.uv.fs_access(target, "W") then
    err = "EACCES: permission denied: " .. target
  else
    local fd, err_open = vim.uv.fs_open(tmppath, "wx", stat ~= nil and stat.mode % 512 or 438)
    if fd == nil then
      err = err_open
    else
      local offset = 0 ---@type integer
      while err == nil and offset < #content do
        local written, err_write = vim.uv.fs_write(fd, offset == 0 and content or content:sub(offset + 1), offset)
        if written == nil then
          err = err_write
        else
          offset = offset + written
        end
      end
      if err == nil then
        local _, err_fsync = vim.uv.fs_fsync(fd)
        err = err_fsync
      end
      local _, err_close = vim.uv.fs_close(fd)
      err = err or err_close
      if err == nil then
        local _, err_rename = vim.uv.fs_rename(tmppath, target)
        err = err_rename
      end
      if err ~= nil then
        vim.uv.fs_unlink(tmppath)
      end
    end
  end

  if err ~= nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "write_file",
      message = "Failed to write file.",
      details = { filepath = filepath, bytes = #content, error = err },
    })
    return false, err
  end
  return true, nil
end

---@param filepath                      string
---@param data                          any
---@param prettier                      boolean
---@return boolean                      Whether the data was written
---@return string|nil                   Why it was not
function M.write_json(filepath, data, prettier)
  local ok_to_encode_json, json_text = pcall(function()
    if prettier then
      return vim.json.encode(data, { indent = "  ", sort_keys = true })
    end
    return vim.json.encode(data, { indent = "", sort_keys = true })
  end)
  if not ok_to_encode_json then
    stl.reporter.warn({
      from = __module_name__,
      subject = "write_json",
      message = "Failed to encode json data.",
      details = { filepath = filepath, data = data },
    })
    return false, json_text
  end
  return M.write_file(filepath, json_text)
end

return M
