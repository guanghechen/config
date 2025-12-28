---@class dot.module.plugin.git
local M = {}

---@param repo                          string
---@return string|nil
function M.head(repo)
  return M.__read_first_line__(repo .. "/.git/HEAD")
end

---@param repo                          string
---@param ...                           string
---@return string|nil
function M.ref(repo, ...)
  local ref = table.concat({ ... }, "/") ---@type string
  return M.__read_first_line__(repo .. "/.git/refs/" .. ref) or M.packed_ref(repo, ref)
end

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

---@param repo                          string
---@return dot.module.plugin.IGitInfo|nil
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

---@param repo                          string
---@return string|nil
function M.get_branch(repo)
  local line = M.head(repo)
  if line then
    return line:match("ref: refs/heads/(.*)")
  end
  return nil
end

---@param repo                          string
---@return string|nil
function M.get_origin(repo)
  local content = M.__read_all__(repo .. "/.git/config")
  if not content then
    return nil
  end

  local in_origin = false ---@type boolean
  for line in content:gmatch("[^\n]+") do
    if line:match("^%s*%[remote \"origin\"%]") then
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

---@param a                             dot.module.plugin.IGitInfo
---@param b                             dot.module.plugin.IGitInfo
---@return boolean
function M.eq(a, b)
  local ra = a.commit and a.commit:sub(1, 7) ---@type string|nil
  local rb = b.commit and b.commit:sub(1, 7) ---@type string|nil
  return ra == rb
end

----------------------------------------------------------------------------------------------------

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
