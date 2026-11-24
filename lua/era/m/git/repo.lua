---@class era.m.git.repo: era.m.git.Repo
---@field public create                fun(toplevel: string, token: stl.c.CancellationToken|nil): stl.c.Future Resolves with ?era.m.git.Repo
local M = {}
M.__index = M

---@type table<string, stl.c.Future>
local create_inflight = {}

---@param gitdir                      string
---@return string|nil
local function resolve_commondir(gitdir)
  local commondir_file = gitdir .. "/commondir" ---@type string
  if vim.uv.fs_stat(commondir_file) == nil then
    return nil
  end

  local lines = vim.fn.readfile(commondir_file, "", 1) ---@type string[]
  if #lines == 0 or lines[1] == "" then
    return nil
  end

  local commondir = dot.path.normalize(gitdir .. "/" .. lines[1]) ---@type string
  local stat = vim.uv.fs_stat(commondir) ---@type uv.fs_stat.result|nil
  if stat and stat.type == "directory" then
    return commondir
  end

  return nil
end

---@param toplevel                   string
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with ?era.m.git.Repo
function M.create(toplevel, token)
  -- Token-owned requests must keep independent cancellation boundaries.
  if token == nil and create_inflight[toplevel] then
    return create_inflight[toplevel]
  end

  -- A failure rejects the future, which then leaves the inflight slot for the next request to retry.
  local future = stl.async.run_future(function()
    if token and token:is_cancelled() then
      return nil
    end

    local result = stl.git.info.get_repo_info(toplevel, token):await()
    if not result then
      return nil
    end

    local self = setmetatable({}, M)
    self.abbrev_head = result.abbrev_head
    self.commondir = resolve_commondir(result.gitdir)
    self.detached = result.detached
    self.gitdir = result.gitdir
    self.toplevel = result.toplevel
    return self
  end)

  if token == nil then
    create_inflight[toplevel] = future
    future:finally(function()
      if create_inflight[toplevel] == future then
        create_inflight[toplevel] = nil
      end
    end)
  end

  return future
end

---@param file                       string
---@return string
function M:get_relpath(file)
  return stl.os.path.relative(self.toplevel, file)
end

return M
