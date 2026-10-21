---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.content" ---@type string

local staging = require("era.m.git.staging")
local util = require("era.m.diffview.util")

---The Git reads content loading issues: `stl.git.info`, or a stand-in with its shape.
---@class era.m.diffview.content.IGit
---@field public get_file_info          fun(cwd: string, relpath: string, token?: stl.c.CancellationToken): stl.c.Future
---@field public get_object_name        fun(cwd: string, object: string, token?: stl.c.CancellationToken): stl.c.Future
---@field public get_show_blob          fun(cwd: string, object: string, token?: stl.c.CancellationToken): stl.c.Future

---@class era.m.diffview.content.ILoadOpts
---@field public token                  ?stl.c.CancellationToken
---@field public is_current             ?fun(): boolean
---@field public before_write           ?fun(): nil Runs just before the buffer is rewritten.
---@field public object_name            ?string The object the status snapshot captured; loading skips resolving it.

---Loads Git objects into side-by-side buffers. A buffer records the object and source format it holds, so loading
---the same content again neither reads nor rewrites it.
---@class era.m.diffview.content.Loader
---@field protected _git                stl.git.info|era.m.diffview.content.IGit
local Loader = {}
Loader.__index = Loader

---@param git                           stl.git.info|era.m.diffview.content.IGit
---@return era.m.diffview.content.Loader
function Loader.new(git)
  local self = setmetatable({}, Loader)
  self._git = git
  return self
end

---@param token                         stl.c.CancellationToken|nil
---@param is_current                    (fun(): boolean)|nil
---@return boolean
local function is_request_current(token, is_current)
  return (not token or not token:is_cancelled()) and (not is_current or is_current())
end

---The encoding and default EOL of the workspace file an object belongs to.
---@param object                        string
---@return string
---@return string
local function get_document_format(object)
  local relpath = object:match("^:%d:(.*)$") or object:match("^[^:]*:(.*)$") ---@type string|nil
  if not relpath or relpath == "" then
    return "utf-8", "\n"
  end

  local filepath = util.workspace_path(relpath) ---@type string
  local local_bufnr = stl.nvim.buf.locate_bufnr(filepath) ---@type integer|nil
  if vim.fn.filereadable(filepath) == 1 then
    local_bufnr = local_bufnr or vim.fn.bufadd(filepath)
    if not vim.api.nvim_buf_is_loaded(local_bufnr) then
      vim.fn.bufload(local_bufnr)
    end
  end
  if not local_bufnr or not vim.api.nvim_buf_is_loaded(local_bufnr) then
    return "utf-8", "\n"
  end

  local encoding = vim.api.nvim_get_option_value("fileencoding", { buf = local_bufnr }) ---@type string
  local fileformat = vim.api.nvim_get_option_value("fileformat", { buf = local_bufnr }) ---@type string
  return staging.normalize_encoding(encoding), staging.eol_from_fileformat(fileformat)
end

---Loads a Git object into `bufnr`.
---@async
---@param object                        string                          Git object, such as "HEAD:path" or ":./path".
---@param bufnr                         integer
---@param opts                          ?era.m.diffview.content.ILoadOpts
---@return boolean ok
---@return boolean content_changed
function Loader:load(object, bufnr, opts)
  opts = opts or {}
  local token, is_current, object_name = opts.token, opts.is_current, opts.object_name
  local git = self._git
  if not is_request_current(token, is_current) then
    return false, false
  end

  -- Keep the index snapshot separate: partial unstage consumes it, while every resolved Git object
  -- may own the content cache identity.
  local index_object_name = nil ---@type string|nil
  local content_object_name = nil ---@type string|nil
  local blob_object = object ---@type string
  local object_missing = false ---@type boolean
  local source_encoding = nil ---@type string|nil
  local source_default_eol = nil ---@type string|nil
  local index_stage_path = object:match("^:%d:(.*)$") ---@type string|nil
  local index_path = not index_stage_path and object:match("^:(.*)$") or nil ---@type string|nil
  if index_path then
    if object_name then
      index_object_name = object_name
    else
      local info_result = git.get_file_info(dot.path.workspace(), index_path, token):await()
      if not is_request_current(token, is_current) then
        return false, false
      end
      if
        type(info_result) ~= "table"
        or not info_result.ok
        or not info_result.info
        or info_result.info.has_conflicts
        or not info_result.info.object_name
      then
        if not token or not token:is_cancelled() then
          stl.reporter.error({
            from = __module_name__,
            subject = "load",
            message = (type(info_result) == "table" and info_result.err) or "Unable to inspect index object",
          })
        end
        return false, false
      end
      index_object_name = info_result.info.object_name
    end
    content_object_name = index_object_name
    blob_object = content_object_name
  elseif object:match("^[^:]+:") then
    if object_name then
      content_object_name = object_name
      blob_object = content_object_name
    else
      local name_result = git.get_object_name(dot.path.workspace(), object, token):await()
      if not is_request_current(token, is_current) then
        return false, false
      end
      if type(name_result) ~= "table" or not name_result.ok or not name_result.object_name then
        if type(name_result) == "table" and name_result.missing then
          object_missing = true
        else
          if not token or not token:is_cancelled() then
            stl.reporter.error({
              from = __module_name__,
              subject = "load",
              message = (type(name_result) == "table" and name_result.err) or "Unable to resolve Git object",
            })
          end
          return false, false
        end
      else
        content_object_name = name_result.object_name
        blob_object = content_object_name
      end
    end
  end

  if content_object_name then
    stl.async.scheduler()

    if not is_request_current(token, is_current) or not vim.api.nvim_buf_is_valid(bufnr) then
      return false, false
    end

    source_encoding, source_default_eol = get_document_format(object)
    if not is_request_current(token, is_current) or not vim.api.nvim_buf_is_valid(bufnr) then
      return false, false
    end
    if
      vim.b[bufnr].git_content_object_name == content_object_name
      and vim.b[bufnr].git_source_encoding == source_encoding
      and vim.b[bufnr].git_source_default_eol == source_default_eol
    then
      vim.b[bufnr].git_object_name = index_object_name
      return true, false
    end
  end

  local bytes = object_missing and "" or nil ---@type string|nil
  if not object_missing then
    local result = git.get_show_blob(dot.path.workspace(), blob_object, token):await()
    if not is_request_current(token, is_current) then
      return false, false
    end

    if type(result) ~= "table" then
      stl.reporter.error({
        from = __module_name__,
        subject = "load",
        message = "Invalid blob result for object: " .. object,
      })
      return false, false
    end

    bytes = result.bytes
    if not result.ok then
      if result.missing then
        bytes = ""
      else
        if not token or not token:is_cancelled() then
          stl.reporter.error({
            from = __module_name__,
            subject = "load",
            message = result.err or ("Unable to read object: " .. object),
          })
        end
        return false, false
      end
    end
  end
  if type(bytes) ~= "string" then
    stl.reporter.error({
      from = __module_name__,
      subject = "load",
      message = "Blob result has no bytes: " .. object,
    })
    return false, false
  end

  stl.async.scheduler()

  if not is_request_current(token, is_current) or not vim.api.nvim_buf_is_valid(bufnr) then
    return false, false
  end

  local encoding, default_eol = get_document_format(object) ---@type string, string
  if not is_request_current(token, is_current) or not vim.api.nvim_buf_is_valid(bufnr) then
    return false, false
  end
  local document, decode_err = staging.from_blob(bytes, encoding, default_eol)
  if not document then
    stl.reporter.error({
      from = __module_name__,
      subject = "load",
      message = decode_err or ("Unable to decode object: " .. object),
    })
    return false, false
  end

  if opts.before_write then
    opts.before_write()
  end
  if not is_request_current(token, is_current) or not vim.api.nvim_buf_is_valid(bufnr) then
    return false, false
  end

  vim.b[bufnr].git_object_name = nil
  vim.b[bufnr].git_content_object_name = nil
  vim.b[bufnr].git_source_encoding = nil
  vim.b[bufnr].git_source_default_eol = nil

  local write_ok, write_err = pcall(function()
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_set_option_value("fileformat", document.eol == "\r\n" and "dos" or "unix", { buf = bufnr })
    vim.api.nvim_set_option_value("fileencoding", document.encoding, { buf = bufnr })
    vim.api.nvim_set_option_value("bomb", document.bomb, { buf = bufnr })
    staging.replace_buffer_text(bufnr, document.text)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  end)
  if not write_ok then
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_set_option_value, "modifiable", false, { buf = bufnr })
    end
    error(write_err, 0)
  end

  vim.b[bufnr].git_object_name = index_object_name
  vim.b[bufnr].git_content_object_name = content_object_name
  vim.b[bufnr].git_source_encoding = content_object_name and encoding or nil
  vim.b[bufnr].git_source_default_eol = content_object_name and default_eol or nil

  return true, true
end

---Git content loading for side-by-side previews.
---@class era.m.diffview.content
local M = {}

M.Loader = Loader

return M
