---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.git.act" ---@type string

---@class stl.git.act
local M = {}

---@param cwd                           string
---@param relpath                       string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with boolean (success)
function M.add_intent_to_add(cwd, relpath, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(false)
      return
    end

    local proc = vim.system({ "git", "-C", cwd, "add", "--intent-to-add", "--", relpath }, { text = true }, function(obj)
      vim.schedule(function()
        resolve(obj.code == 0)
      end)
    end)

    if token then
      token:on_cancel(function()
        proc:kill(9)
      end)
    end
  end)
end

---@param cwd                           string
---@param patch                         string
---@param reverse                       boolean|nil
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with { ok: boolean, err: string|nil }
function M.apply_patch(cwd, patch, reverse, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ ok = false, err = "Cancelled" })
      return
    end

    local args = { "git", "-C", cwd, "apply", "--cached", "--unidiff-zero", "-" }
    if reverse then
      table.insert(args, 5, "--reverse")
    end

    local proc = vim.system(args, { stdin = patch }, function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          local err_msg = obj.stderr or ""
          stl.reporter.error({
            from = __module_name__,
            subject = "apply_patch",
            message = "Failed to apply patch.",
            details = { error = err_msg },
          })
          resolve({ ok = false, err = err_msg })
        else
          resolve({ ok = true, err = nil })
        end
      end)
    end)

    if token then
      token:on_cancel(function()
        proc:kill(9)
      end)
    end
  end)
end

---Clone a git repository asynchronously
---@param url                           string
---@param path                          string
---@param branch                        string|nil
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with { ok: boolean, stdout: string, stderr: string }
function M.clone(url, path, branch, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ ok = false, stdout = "", stderr = "Cancelled" })
      return
    end

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

    local proc = vim.system({ "git", unpack(args) }, { text = true }, function(result)
      vim.schedule(function()
        resolve({
          ok = result.code == 0,
          stdout = result.stdout or "",
          stderr = result.stderr or "",
        })
      end)
    end)

    if token then
      token:on_cancel(function()
        proc:kill(9)
      end)
    end
  end)
end

---@param cwd                           string
---@param file                          string
---@param content                       string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with hash (string|nil)
function M.hash_object(cwd, file, content, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(nil)
      return
    end

    local proc = vim.system(
      { "git", "-C", cwd, "hash-object", "-w", "--path", file, "--stdin" },
      { stdin = content, text = false },
      function(obj)
        vim.schedule(function()
          if obj.code ~= 0 then
            stl.reporter.warn({
              from = __module_name__,
              subject = "hash_object",
              message = "Failed to hash object",
              details = { file = file, code = obj.code, stderr = obj.stderr },
            })
            resolve(nil)
          else
            local hash = (obj.stdout or ""):match("^([0-9a-fA-F]+)") or ""
            resolve(hash ~= "" and hash or nil)
          end
        end)
      end
    )

    if token then
      token:on_cancel(function()
        proc:kill(9)
      end)
    end
  end)
end

---@param cwd                           string
---@param relpath                       string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with boolean (success)
function M.reset_file(cwd, relpath, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(false)
      return
    end

    local proc = vim.system({ "git", "-C", cwd, "checkout", "--", relpath }, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          stl.reporter.warn({
            from = __module_name__,
            subject = "reset_file",
            message = "Failed to reset file",
            details = { relpath = relpath, code = obj.code, stderr = obj.stderr },
          })
        end
        resolve(obj.code == 0)
      end)
    end)

    if token then
      token:on_cancel(function()
        proc:kill(9)
      end)
    end
  end)
end

---@param cwd                           string
---@param relpath                       string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with boolean (success)
function M.stage_file(cwd, relpath, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(false)
      return
    end

    local proc = vim.system({ "git", "-C", cwd, "add", "--", relpath }, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          stl.reporter.warn({
            from = __module_name__,
            subject = "stage_file",
            message = "Failed to stage file",
            details = { relpath = relpath, code = obj.code },
          })
        end
        resolve(obj.code == 0)
      end)
    end)

    if token then
      token:on_cancel(function()
        proc:kill(9)
      end)
    end
  end)
end

---@param cwd                           string
---@param relpath                       string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with boolean (success)
function M.unstage_file(cwd, relpath, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(false)
      return
    end

    local proc = vim.system({ "git", "-C", cwd, "reset", "HEAD", "--", relpath }, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          stl.reporter.warn({
            from = __module_name__,
            subject = "unstage_file",
            message = "Failed to unstage file",
            details = { relpath = relpath, code = obj.code },
          })
        end
        resolve(obj.code == 0)
      end)
    end)

    if token then
      token:on_cancel(function()
        proc:kill(9)
      end)
    end
  end)
end

---@param cwd                           string
---@param mode_bits                     string
---@param object_name                   string
---@param relpath                       string
---@param token                         ?stl.c.CancellationToken
---@param add                           ?boolean
---@return stl.c.Future                 Resolves with boolean (success)
function M.update_index(cwd, mode_bits, object_name, relpath, token, add)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(false)
      return
    end

    local cacheinfo = string.format("%s,%s,%s", mode_bits, object_name, relpath)
    local args = { "git", "-C", cwd, "update-index" } ---@type string[]
    if add then
      args[#args + 1] = "--add"
    end
    vim.list_extend(args, { "--cacheinfo", cacheinfo })
    local proc = vim.system(args, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          stl.reporter.warn({
            from = __module_name__,
            subject = "update_index",
            message = "Failed to update index",
            details = { relpath = relpath, code = obj.code },
          })
        end
        resolve(obj.code == 0)
      end)
    end)

    if token then
      token:on_cancel(function()
        proc:kill(9)
      end)
    end
  end)
end

return M
