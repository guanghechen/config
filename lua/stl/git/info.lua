---@class stl.git.IGitInfo
---@field public branch                 ?string
---@field public commit                 ?string

---@class stl.git.info
local M = {}

----------------------------------------------------------------------------------------------------
-- Private (file reading helpers)
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
-- Public (sync methods - file reading)
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
---@param origin                        ?boolean
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
-- Public (async methods - Future version)
----------------------------------------------------------------------------------------------------

---@param cwd                           string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with { abbrev_head: string, detached: boolean }
function M.get_abbrev_head(cwd, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ abbrev_head = "", detached = false })
      return
    end

    local proc ---@type vim.SystemObj|nil
    proc = vim.system({ "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }, function(obj)
      vim.schedule(function()
        if token and token:is_cancelled() then
          return
        end

        if obj.code ~= 0 then
          resolve({ abbrev_head = "", detached = false })
          return
        end

        local head = vim.trim(obj.stdout or "")
        if head == "HEAD" then
          proc = vim.system({ "git", "-C", cwd, "rev-parse", "--short", "HEAD" }, { text = true }, function(obj2)
            vim.schedule(function()
              if token and token:is_cancelled() then
                return
              end
              if obj2.code == 0 then
                resolve({ abbrev_head = vim.trim(obj2.stdout or ""), detached = true })
              else
                resolve({ abbrev_head = "", detached = true })
              end
            end)
          end)
        else
          resolve({ abbrev_head = head, detached = false })
        end
      end)
    end)

    if token then
      token:on_cancel(function()
        if proc then
          proc:kill(9)
        end
      end)
    end
  end)
end

---@param cwd                           string
---@param relpath                       string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with ?stl.git.IFileInfo
function M.get_file_info(cwd, relpath, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(nil)
      return
    end

    local proc = vim.system({ "git", "-C", cwd, "ls-files", "--stage", "--", relpath }, { text = true }, function(obj)
      vim.schedule(function()
        if token and token:is_cancelled() then
          return
        end

        ---@type stl.git.IFileInfo
        local info = {
          has_conflicts = false,
          mode_bits = nil,
          object_name = nil,
          relpath = relpath,
        }

        if obj.code == 0 then
          local lines = vim.split(obj.stdout or "", "\n", { plain = true })
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
          resolve(nil)
        else
          resolve(info)
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

---@param cwd                           string
---@param object                        string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with ?string[]
function M.get_show_text(cwd, object, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(nil)
      return
    end

    local proc ---@type vim.SystemObj|nil
    proc = vim.system({ "git", "-C", cwd, "cat-file", "-p", object }, { text = true }, function(obj)
      vim.schedule(function()
        if token and token:is_cancelled() then
          return
        end

        if obj.code == 0 then
          local lines = vim.split(obj.stdout or "", "\n", { plain = true })
          -- Keep trailing empty string to preserve no_nl_at_eof information
          resolve(lines)
        else
          proc = vim.system({ "git", "-C", cwd, "show", object }, { text = true }, function(obj2)
            vim.schedule(function()
              if token and token:is_cancelled() then
                return
              end
              if obj2.code == 0 then
                local lines = vim.split(obj2.stdout or "", "\n", { plain = true })
                resolve(lines)
              else
                resolve(nil)
              end
            end)
          end)
        end
      end)
    end)

    if token then
      token:on_cancel(function()
        if proc then
          proc:kill(9)
        end
      end)
    end
  end)
end

---@param cwd                           string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with { gitdir: ?string, toplevel: ?string }
function M.get_toplevel(cwd, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ gitdir = nil, toplevel = nil })
      return
    end

    local proc = vim.system(
      { "git", "-C", cwd, "rev-parse", "--show-toplevel", "--absolute-git-dir" },
      { text = true },
      function(obj)
        vim.schedule(function()
          if token and token:is_cancelled() then
            return
          end

          if obj.code ~= 0 then
            resolve({ gitdir = nil, toplevel = nil })
            return
          end

          local lines = vim.split(obj.stdout or "", "\n", { plain = true })
          if #lines < 2 then
            resolve({ gitdir = nil, toplevel = nil })
            return
          end

          local toplevel = yoz.path.normalize(lines[1], true, stl.env.PATH_SEP)
          local gitdir = yoz.path.normalize(lines[2], true, stl.env.PATH_SEP)
          resolve({ gitdir = gitdir, toplevel = toplevel })
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

return M
