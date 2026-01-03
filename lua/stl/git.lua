---@class stl.git.IGitInfo
---@field public branch                 string|nil
---@field public commit                 string|nil

---@class stl.git
local M = {}

---Read HEAD reference
---@param repo                          string
---@return string|nil
function M.head(repo)
  return M.__read_first_line__(repo .. "/.git/HEAD")
end

---Read git ref (heads, remotes, tags)
---@param repo                          string
---@param ...                           string
---@return string|nil
function M.ref(repo, ...)
  local ref = table.concat({ ... }, "/") ---@type string
  return M.__read_first_line__(repo .. "/.git/refs/" .. ref) or M.packed_ref(repo, ref)
end

---Read from packed-refs file
---@param repo                          string
---@param ref                           string
---@return string|nil
function M.packed_ref(repo, ref)
  local content = M.__read_all__(repo .. "/.git/packed-refs")
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
  local content = M.__read_all__(repo .. "/.git/config")
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

---Run git command asynchronously
---@param args                          string[]
---@param opts                          { cwd: string|nil }|nil
---@param callback                      fun(lines: string[], code: integer): nil
---@return fun(): nil                   cancel_fn
function M.run_async(args, opts, callback)
  local cmd = { "git" }
  if opts and opts.cwd then
    cmd[#cmd + 1] = "-C"
    cmd[#cmd + 1] = opts.cwd
  end
  for _, arg in ipairs(args) do
    cmd[#cmd + 1] = arg
  end

  local cancelled = false ---@type boolean
  local proc = vim.system(cmd, { text = true }, function(obj)
    if not cancelled then
      vim.schedule(function()
        if not cancelled then
          local lines = {}
          if obj.code == 0 and obj.stdout then
            lines = vim.split(obj.stdout, "\n", { plain = true })
            if lines[#lines] == "" then
              lines[#lines] = nil
            end
          end
          callback(lines, obj.code)
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

---Run git command synchronously (for user-triggered actions where blocking is acceptable)
---@param args                          string[]
---@param opts                          { cwd: string|nil }|nil
---@return string[]
---@return integer
function M.run_sync(args, opts)
  local cmd = { "git" }
  if opts and opts.cwd then
    cmd[#cmd + 1] = "-C"
    cmd[#cmd + 1] = opts.cwd
  end
  for _, arg in ipairs(args) do
    cmd[#cmd + 1] = arg
  end

  local obj = vim.system(cmd, { text = true }):wait()
  local lines = {}
  if obj.code == 0 and obj.stdout then
    lines = vim.split(obj.stdout, "\n", { plain = true })
    if lines[#lines] == "" then
      lines[#lines] = nil
    end
  end
  return lines, obj.code
end

----------------------------------------------------------------------------------------------------

---Read entire file content
---@param path                          string
---@return string|nil
function M.__read_all__(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a") ---@type string
  f:close()
  return content
end

---Read first line of file
---@param path                          string
---@return string|nil
function M.__read_first_line__(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local line = f:read("*l") ---@type string|nil
  f:close()
  return line
end

return M
