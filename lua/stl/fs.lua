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

---@param filepath                      string
---@return nil
function M.edit_file(filepath)
  vim.cmd("noswapfile tabnew " .. filepath)
  vim.api.nvim_set_option_value("backupcopy", "yes", { buf = 0 })
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
  local file = io.open(filepath, "r")
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

---@param filepath                      string
---@return nil
function M.touch(filepath)
  local stat = vim.uv.fs_stat(filepath)
  if stat ~= nil and stat.type == "file" then
    local file = io.open(filepath, "a")
    if file then
      file:close() -- Close the file immediately
      local current_time = vim.uv.hrtime() / 1e9 -- Get current time in seconds
      vim.uv.fs_utime(filepath, current_time, current_time, function(err)
        if err then
          stl.reporter.error({
            from = __module_name__,
            subject = "touch",
            message = "Failed to touch file.",
            details = { filepath = filepath, err = err },
          })
        end
      end)
    end
  end
end

---@class stl.t.IWatchFileOptions
---@field public filepath               string
---@field public on_event               fun(filepath:string, events: any, unwatch:fun():nil):nil
---@field public on_error               ?fun(filepath:string, err: any, unwatch:fun():nil):nil

---@param opts                          stl.t.IWatchFileOptions
---@return fun():nil
function M.watch_file(opts)
  local filepath = opts.filepath
  local on_event = opts.on_event
  local on_error = opts.on_error or default_watch_on_error

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

  ---@diagnostic disable-next-line: unused-local
  local callback = function(err, filename, events)
    if err then
      on_error(filepath, err, unwatch)
    else
      on_event(filepath, events, unwatch)
    end
  end

  ---attacher handler
  if handle ~= nil then
    vim.uv.fs_event_start(handle, filepath, flags, callback)
  end
  return unwatch
end

---@param filepath                      string
---@param content                       string
---@return nil
function M.write_file(filepath, content)
  stl.env.mkdirs(filepath, false)

  local file, err_open = io.open(filepath, "wb")
  if not file then
    stl.reporter.error({
      from = __module_name__,
      subject = "write_file",
      message = "Failed to open filepath.",
      details = { filepath = filepath, error = err_open },
    })
    return
  end

  local ok, err_write = pcall(file.write, file, content)
  file:close()

  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "write_file",
      message = "Failed to write content.",
      details = { filepath = filepath, content = content, error = err_write },
    })
  end
end

---@param filepath                      string
---@param data                          any
---@param prettier                      boolean
---@return nil
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
    return
  end
  M.write_file(filepath, json_text)
end

return M
