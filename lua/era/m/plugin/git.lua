---@class era.m.plugin.IGitInfo
---@field public branch                 string|nil
---@field public commit                 string|nil

---@class era.m.plugin.git
local M = {}

-- Forward all functions to stl.git
M.head = function(repo)
  return stl.git.head(repo)
end

M.ref = function(repo, ...)
  return stl.git.ref(repo, ...)
end

M.packed_ref = function(repo, ref)
  return stl.git.packed_ref(repo, ref)
end

M.info = function(repo)
  return stl.git.info(repo)
end

M.get_commit = function(repo, branch, origin)
  return stl.git.get_commit(repo, branch, origin)
end

M.get_branch = function(repo)
  return stl.git.get_branch(repo)
end

M.get_origin = function(repo)
  return stl.git.get_origin(repo)
end

M.eq = function(a, b)
  return stl.git.eq(a, b)
end

M.clone = function(url, path, branch, callback)
  return stl.git.clone(url, path, branch, callback)
end

----------------------------------------------------------------------------------------------------

-- Keep these as protected methods for backward compatibility
-- They're simple file reading utilities that era.m.plugin.git might use internally

---@param path                          string
---@return string|nil
function M.__read_all__(path)
  return stl.git.__read_all__(path)
end

---@param path                          string
---@return string|nil
function M.__read_first_line__(path)
  return stl.git.__read_first_line__(path)
end

return M

