---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.git.act" ---@type string

local S = stl.git

---@class stl.git.act
local M = {}

----------------------------------------------------------------------------------------------------
-- Git actions (async)
----------------------------------------------------------------------------------------------------

---@param cwd                           string
---@param relpath                       string
---@param callback                      fun(ok: boolean): nil
---@return fun(): nil                   cancel_fn
function M.add_intent_to_add_async(cwd, relpath, callback)
  return S.exec.exec_async({ "add", "--intent-to-add", "--", relpath }, { cwd = cwd }, function(_, code)
    callback(code == 0)
  end)
end

---@param cwd                           string
---@param patch                         string
---@param reverse                       boolean|nil
---@param callback                      fun(ok: boolean, err: string|nil): nil
---@return fun(): nil                   cancel_fn
function M.apply_patch_async(cwd, patch, reverse, callback)
  local args = { "git", "-C", cwd, "apply", "--cached", "--unidiff-zero", "-" }
  if reverse then
    table.insert(args, 5, "--reverse")
  end

  local cancelled = false
  local proc = vim.system(args, { stdin = patch }, function(obj)
    if not cancelled then
      vim.schedule(function()
        if not cancelled then
          if obj.code ~= 0 then
            local err_msg = obj.stderr or ""
            stl.reporter.error({
              from = __module_name__,
              subject = "apply_patch",
              message = "Failed to apply patch.",
              details = { error = err_msg },
            })
            callback(false, err_msg)
          else
            callback(true, nil)
          end
        end
      end)
    end
  end)

  return function()
    cancelled = true
    if proc then
      proc:kill(9)
    end
  end
end

---@param cwd                           string
---@param file                          string
---@param lines                         string[]
---@param callback                      fun(hash: string|nil): nil
---@return fun(): nil                   cancel_fn
function M.hash_object_async(cwd, file, lines, callback)
  local stdin = table.concat(lines, "\n")
  -- Only add trailing newline if the last element is NOT already an empty string
  -- (empty string at end indicates the original file had a trailing newline)
  if #lines > 0 and lines[#lines] ~= "" then
    stdin = stdin .. "\n"
  end

  local cancelled = false
  local proc = vim.system(
    { "git", "-C", cwd, "hash-object", "-w", "--path", file, "--stdin" },
    { stdin = stdin, text = true },
    function(obj)
      if not cancelled then
        vim.schedule(function()
          if not cancelled then
            if obj.code ~= 0 then
              stl.reporter.warn({
                from = __module_name__,
                subject = "hash_object",
                message = "Failed to hash object",
                details = { file = file, code = obj.code, stderr = obj.stderr },
              })
              callback(nil)
            else
              local hash = vim.trim(obj.stdout or "")
              callback(hash ~= "" and hash or nil)
            end
          end
        end)
      end
    end
  )

  return function()
    cancelled = true
    if proc then
      proc:kill(9)
    end
  end
end

---@param cwd                           string
---@param relpath                       string
---@param callback                      fun(ok: boolean): nil
---@return fun(): nil                   cancel_fn
function M.stage_file_async(cwd, relpath, callback)
  return S.exec.exec_async({ "add", "--", relpath }, { cwd = cwd }, function(_, code)
    if code ~= 0 then
      stl.reporter.warn({
        from = __module_name__,
        subject = "stage_file",
        message = "Failed to stage file",
        details = { relpath = relpath, code = code },
      })
    end
    callback(code == 0)
  end)
end

---@param cwd                           string
---@param relpath                       string
---@param callback                      fun(ok: boolean): nil
---@return fun(): nil                   cancel_fn
function M.unstage_file_async(cwd, relpath, callback)
  return S.exec.exec_async({ "reset", "HEAD", "--", relpath }, { cwd = cwd }, function(_, code)
    if code ~= 0 then
      stl.reporter.warn({
        from = __module_name__,
        subject = "unstage_file",
        message = "Failed to unstage file",
        details = { relpath = relpath, code = code },
      })
    end
    callback(code == 0)
  end)
end

---@param cwd                           string
---@param mode_bits                     string
---@param object_name                   string
---@param relpath                       string
---@param callback                      fun(ok: boolean): nil
---@return fun(): nil                   cancel_fn
function M.update_index_async(cwd, mode_bits, object_name, relpath, callback)
  return S.exec.exec_async(
    { "update-index", "--cacheinfo", string.format("%s,%s,%s", mode_bits, object_name, relpath) },
    { cwd = cwd },
    function(_, code)
      if code ~= 0 then
        stl.reporter.warn({
          from = __module_name__,
          subject = "update_index",
          message = "Failed to update index",
          details = { relpath = relpath, code = code },
        })
      end
      callback(code == 0)
    end
  )
end

----------------------------------------------------------------------------------------------------
-- Clone operation
----------------------------------------------------------------------------------------------------

---Clone a git repository asynchronously
---@param url                           string
---@param path                          string
---@param branch                        string|nil
---@param callback                      fun(ok: boolean, stdout: string, stderr: string): nil
---@return nil
function M.clone(url, path, branch, callback)
  local args = {
    "clone",
    url,
    "--filter=blob:none",
    "--origin=origin",
    "-c",
    "core.autocrlf=false",
    "--progress",
  }

  if branch then
    args[#args + 1] = "--single-branch"
    args[#args + 1] = "--branch=" .. branch
  end

  args[#args + 1] = path

  vim.system({ "git", unpack(args) }, { text = true }, function(result)
    vim.schedule(function()
      local ok = result.code == 0 ---@type boolean
      local stdout = result.stdout or "" ---@type string
      local stderr = result.stderr or "" ---@type string
      callback(ok, stdout, stderr)
    end)
  end)
end

return M
