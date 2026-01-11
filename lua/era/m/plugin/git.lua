---@class era.m.plugin.IGitInfo
---@field public branch                 string|nil
---@field public commit                 string|nil

---@class era.m.plugin.git
local M = {}

-- Forward all functions to stl.git.info
M.head = function(repo)
  return stl.git.info.head(repo)
end

M.ref = function(repo, ...)
  return stl.git.info.ref(repo, ...)
end

M.packed_ref = function(repo, ref)
  return stl.git.info.packed_ref(repo, ref)
end

M.info = function(repo)
  return stl.git.info.info(repo)
end

M.get_commit = function(repo, branch, origin)
  return stl.git.info.get_commit(repo, branch, origin)
end

M.get_branch = function(repo)
  return stl.git.info.get_branch(repo)
end

M.get_origin = function(repo)
  return stl.git.info.get_origin(repo)
end

M.eq = function(a, b)
  return stl.git.info.eq(a, b)
end

M.clone = function(url, path, branch, callback)
  return stl.git.act.clone(url, path, branch, callback)
end

return M
