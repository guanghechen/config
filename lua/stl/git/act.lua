---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.git.act" ---@type string

local exec = require("stl.git.exec")

---@class stl.git.act
local M = {}

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

    path = yoz.canonical_path.to_os_path(path)
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

    local proc = vim.system(exec.command(args), { text = true }, function(result)
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
      exec.command({ "hash-object", "-w", "--path", file, "--stdin" }, cwd),
      { stdin = content, text = false },
      function(obj)
        vim.schedule(function()
          -- A process killed by a signal exits with code 0, and leaves no object name to read.
          local hash = obj.code == 0 and obj.signal == 0 and (obj.stdout or ""):match("^([0-9a-fA-F]+)") or nil
          if not hash then
            stl.reporter.warn({
              from = __module_name__,
              subject = "hash_object",
              message = "Failed to hash object",
              details = { file = file, code = obj.code, signal = obj.signal, stderr = obj.stderr },
            })
          end
          resolve(hash)
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
function M.stage_file(cwd, relpath, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(false)
      return
    end

    local proc = vim.system(exec.command({ "add", "--", relpath }, cwd), { text = true }, function(obj)
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
    local args = { "update-index" } ---@type string[]
    if add then
      args[#args + 1] = "--add"
    end
    vim.list_extend(args, { "--cacheinfo", cacheinfo })
    local proc = vim.system(exec.command(args, cwd), { text = true }, function(obj)
      vim.schedule(function()
        -- A process killed by a signal exits with code 0 without having written the index.
        local updated = obj.code == 0 and obj.signal == 0 ---@type boolean
        if not updated then
          stl.reporter.warn({
            from = __module_name__,
            subject = "update_index",
            message = "Failed to update index",
            details = { relpath = relpath, code = obj.code, signal = obj.signal, stderr = obj.stderr },
          })
        end
        resolve(updated)
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
