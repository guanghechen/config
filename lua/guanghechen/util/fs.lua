---@param filepath string
---@param err any
---@param unwatch fun():nil
local function default_watch_on_error(filepath, err, unwatch)
  error("[watch_file] encounter error on " .. filepath .. ", error:" .. vim.inspect(err))
  unwatch()
end

---@class guanghechen.util.fs
local M = {}

---@return string|nil
function M.read_file(filepath)
  local file = io.open(filepath, "rb") -- rb: read in binary mode
  if not file then
    error("File not found. filepath: " .. filepath)
    return nil
  end

  local content = file:read("*a") -- Read the entire content of the file
  file:close()
  return content -- Assuming the content is UTF-8 encoded, it can now be used as a string
end

---@class IWatchFileOptions
---@field filepath string
---@field on_event fun(filepath:string, events: any, unwatch:fun():nil):nil
---@field on_error? fun(filepath:string, err: any, unwatch:fun():nil):nil

---@param opts IWatchFileOptions
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
    vim.uv.fs_event_stop(handle)
  end

  local callback = function(err, filename, events)
    -- vim.notify("callback:" .. vim.inspect({ err = err, event = events, filename = filename }))
    if err then
      on_error(filepath, err, unwatch)
    else
      on_event(filepath, events, unwatch)
    end
  end

  ---attacher handler
  vim.uv.fs_event_start(handle, filepath, flags, callback)
  return unwatch
end

return M
