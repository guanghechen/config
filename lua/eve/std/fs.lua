local std_json = require("eve.std.json")
local reporter = require("eve.std.reporter")

---@class eve.std.fs
local M = {}

---@class eve.std.fs.IReadFileParams
---@field public filepath               string
---@field public silent                 ?boolean

---@class eve.std.fs.IReadFileAsLinesParams
---@field public filepath               string
---@field public max_lines              ?integer
---@field public silent                 ?boolean

---@class eve.std.fs.IReadJsonParams
---@field public filepath               string
---@field public silent_on_bad_path     ?boolean
---@field public silent_on_bad_json     ?boolean

---@param filepath                      string
---@param err                           any
---@param unwatch                       fun():nil
local function default_watch_on_error(filepath, err, unwatch)
  reporter.error({
    from = "eve.std.fs",
    subject = "watch_file",
    message = "Failed to watch file.",
    details = { filepath = filepath, err = err },
  })
  unwatch()
end

---@param filepath                      string
---@return eve.enums.FileType|nil
function M.is_file_or_dir(filepath)
  local stat = vim.uv.fs_stat(filepath)
  if stat == nil then
    return nil
  end

  if stat.type == "directory" then
    return "directory"
  end

  if stat.type == "file" then
    return "file"
  end

  return "other"
end

---@param params                        eve.std.fs.IReadFileParams
---@return string|nil
function M.read_file(params)
  local filepath = params.filepath ---@type string
  local silent = not not params.silent ---@type boolean
  local file = io.open(filepath, "rb") -- rb: read in binary mode
  if not file then
    if not silent then
      reporter.error({
        from = "eve.std.fs",
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

---@param params                        eve.std.fs.IReadFileAsLinesParams
---@return string[]
function M.read_file_as_lines(params)
  local filepath = params.filepath ---@type string
  local silent = not not params.silent ---@type boolean
  local file = io.open(filepath, "r")
  if not file then
    if not silent then
      reporter.error({
        from = "eve.std.fs",
        subject = "read_file",
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

---@param params                        eve.std.fs.IReadJsonParams
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

  local ok_to_decode_json, data = pcall(vim.json.decode, json_text)
  if not ok_to_decode_json then
    if not silent_on_bad_json then
      reporter.warn({
        from = "eve.std.fs",
        subject = "read_json",
        message = "Failed to decode json",
        details = { filepath = filepath, json_text = json_text },
      })
    end
    return nil
  end

  return data
end

---@class eve.std.fs.IWatchFileOptions
---@field filepath string
---@field on_event fun(filepath:string, events: any, unwatch:fun():nil):nil
---@field on_error? fun(filepath:string, err: any, unwatch:fun():nil):nil

---@param opts eve.std.fs.IWatchFileOptions
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
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":p:h"), "p")

  local file = io.open(filepath, "w")
  if not file then
    reporter.error({
      from = "eve.std.fs",
      subject = "write_file",
      message = "Failed to open filepath.",
      details = { filepath = filepath },
    })
    return
  end

  local ok, err = pcall(file.write, file, content)
  if not ok then
    reporter.error({
      from = "eve.std.fs",
      subject = "write_file",
      message = "Failed to write content.",
      details = { filepath = filepath, content = content, err = err },
    })
  end

  file:close()
end

---@param filepath                      string
---@param data                          any
---@param prettier                      boolean
---@return nil
function M.write_json(filepath, data, prettier)
  local ok_to_encode_json, json_text = pcall(prettier and std_json.stringify_prettier or std_json.stringify, data)
  if not ok_to_encode_json then
    reporter.warn({
      from = "eve.std.fs",
      subject = "write_json",
      message = "Failed to encode json data.",
      details = { filepath = filepath, data = data },
    })
    return
  end
  M.write_file(filepath, json_text)
end

return M
