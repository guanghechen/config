local S = stl.git

---@class stl.git.IGitInfo
---@field public branch                 string|nil
---@field public commit                 string|nil

---@class stl.git.info
local M = {}

----------------------------------------------------------------------------------------------------

---@param path                          string
---@return string|nil
local function read_all(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a") ---@type string
  f:close()
  return content
end

---@param path                          string
---@return string|nil
local function read_first_line(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local line = f:read("*l") ---@type string|nil
  f:close()
  return line
end

----------------------------------------------------------------------------------------------------
-- Sync methods (file reading)
----------------------------------------------------------------------------------------------------

---Read HEAD reference
---@param repo                          string
---@return string|nil
function M.head(repo)
  return read_first_line(repo .. "/.git/HEAD")
end

---Read git ref (heads, remotes, tags)
---@param repo                          string
---@param ...                           string
---@return string|nil
function M.ref(repo, ...)
  local ref = table.concat({ ... }, "/") ---@type string
  return read_first_line(repo .. "/.git/refs/" .. ref) or M.packed_ref(repo, ref)
end

---Read from packed-refs file
---@param repo                          string
---@param ref                           string
---@return string|nil
function M.packed_ref(repo, ref)
  local content = read_all(repo .. "/.git/packed-refs")
  if not content then
    return nil
  end

  for line in content:gmatch("[^\n]+") do
    local commit, name = line:match("^(%x+) refs/(.*)$")
    if name == ref then
      return commit
    end
  end
  return nil
end

---Get current git info (branch and commit)
---@param repo                          string
---@return stl.git.IGitInfo|nil
function M.info(repo)
  local line = M.head(repo)
  if not line then
    return nil
  end

  local ref, branch = line:match("ref: refs/(heads/(.*))")
  if ref then
    return {
      branch = branch,
      commit = M.ref(repo, ref),
    }
  else
    return { commit = line }
  end
end

---Get commit for specific branch
---@param repo                          string
---@param branch                        string
---@param origin                        boolean|nil
---@return string|nil
function M.get_commit(repo, branch, origin)
  if origin then
    return M.ref(repo, "remotes/origin", branch) or M.ref(repo, "heads", branch)
  else
    return M.ref(repo, "heads", branch)
  end
end

---Get current branch name
---@param repo                          string
---@return string|nil
function M.get_branch(repo)
  local line = M.head(repo)
  if line then
    return line:match("ref: refs/heads/(.*)")
  end
  return nil
end

---Get origin URL from git config
---@param repo                          string
---@return string|nil
function M.get_origin(repo)
  local content = read_all(repo .. "/.git/config")
  if not content then
    return nil
  end

  local in_origin = false ---@type boolean
  for line in content:gmatch("[^\n]+") do
    if line:match('^%s*%[remote "origin"%]') then
      in_origin = true
    elseif line:match("^%s*%[") then
      in_origin = false
    elseif in_origin then
      local url = line:match("^%s*url%s*=%s*(.+)%s*$")
      if url then
        return url
      end
    end
  end
  return nil
end

---Compare two git info objects (by first 7 chars of commit)
---@param a                             stl.git.IGitInfo
---@param b                             stl.git.IGitInfo
---@return boolean
function M.eq(a, b)
  local ra = a.commit and a.commit:sub(1, 7) ---@type string|nil
  local rb = b.commit and b.commit:sub(1, 7) ---@type string|nil
  return ra == rb
end

----------------------------------------------------------------------------------------------------
-- Async methods (git command execution)
----------------------------------------------------------------------------------------------------

---@param cwd                           string
---@param callback                      fun(abbrev_head: string, detached: boolean): nil
---@return fun(): nil                   cancel_fn
function M.get_abbrev_head_async(cwd, callback)
  local cancelled = false
  local proc = nil

  proc = vim.system({ "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }, function(obj)
    if not cancelled then
      vim.schedule(function()
        if cancelled then
          return
        end

        if obj.code ~= 0 then
          callback("", false)
          return
        end

        local head = vim.trim(obj.stdout or "")
        if head == "HEAD" then
          proc = vim.system({ "git", "-C", cwd, "rev-parse", "--short", "HEAD" }, { text = true }, function(obj2)
            if not cancelled then
              vim.schedule(function()
                if cancelled then
                  return
                end
                if obj2.code == 0 then
                  callback(vim.trim(obj2.stdout or ""), true)
                else
                  callback("", true)
                end
              end)
            end
          end)
        else
          callback(head, false)
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
---@param relpath                       string
---@param callback                      fun(info: stl.git.IFileInfo|nil): nil
---@return fun(): nil                   cancel_fn
function M.get_file_info_async(cwd, relpath, callback)
  return S.exec.exec_async({ "ls-files", "--stage", "--", relpath }, { cwd = cwd }, function(lines, code)
    ---@type stl.git.IFileInfo
    local info = {
      has_conflicts = false,
      mode_bits = nil,
      object_name = nil,
      relpath = relpath,
    }

    if code == 0 then
      for _, line in ipairs(lines) do
        local mode, object, stage = line:match("^(%d+)%s+(%x+)%s+(%d)%s+")
        if mode and object and stage then
          if stage == "0" then
            info.mode_bits = mode
            info.object_name = object
          else
            info.has_conflicts = true
          end
        end
      end
    end

    if not info.object_name and not info.has_conflicts then
      callback(nil)
    else
      callback(info)
    end
  end)
end

---@param cwd                           string
---@param object                        string
---@param callback                      fun(lines: string[]|nil): nil
---@return fun(): nil                   cancel_fn
function M.get_show_text_async(cwd, object, callback)
  local cancelled = false
  local proc = nil

  proc = vim.system({ "git", "-C", cwd, "cat-file", "-p", object }, { text = true }, function(obj)
    if not cancelled then
      vim.schedule(function()
        if cancelled then
          return
        end

        if obj.code == 0 then
          local lines = vim.split(obj.stdout or "", "\n", { plain = true })
          -- Keep trailing empty string to preserve no_nl_at_eof information
          callback(lines)
        else
          proc = vim.system({ "git", "-C", cwd, "show", object }, { text = true }, function(obj2)
            if not cancelled then
              vim.schedule(function()
                if cancelled then
                  return
                end
                if obj2.code == 0 then
                  local lines = vim.split(obj2.stdout or "", "\n", { plain = true })
                  callback(lines)
                else
                  callback(nil)
                end
              end)
            end
          end)
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
---@param callback                      fun(gitdir: string|nil, toplevel: string|nil): nil
---@return fun(): nil                   cancel_fn
function M.get_toplevel_async(cwd, callback)
  return S.exec.exec_async({ "rev-parse", "--show-toplevel", "--absolute-git-dir" }, { cwd = cwd }, function(lines, code)
    if code ~= 0 or #lines < 2 then
      callback(nil, nil)
      return
    end
    local toplevel = yoz.path.normalize(lines[1], true, stl.env.PATH_SEP)
    local gitdir = yoz.path.normalize(lines[2], true, stl.env.PATH_SEP)
    callback(gitdir, toplevel)
  end)
end

return M
