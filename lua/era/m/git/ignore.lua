---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.ignore" ---@type string

local jobs = require("era.m.git.job")
local cache = nil ---@type yoz.git.IgnoreCache|nil
local workspace = nil ---@type string|nil

---@class era.m.git.ignore
local M = {}
M.o_refreshed = stl.c.Observable.from_value({}) ---@type stl.c.Observable<string[]>

---@return yoz.git.IgnoreCache
local function current_cache()
  local root = dot.path.workspace()
  if not cache or root ~= workspace then
    cache = yoz.git.ignore_cache(root)
    workspace = root
  end
  return cache
end

---@return nil
function M.clear()
  if cache then
    cache:clear()
  end
end

---@param filepath                      string
---@return boolean
function M.is_ignored(filepath)
  return dot.path.is_git_repo() and current_cache():lookup(filepath)
end

---@param filepaths                     string[]
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with nil, including cancellation; native failures reject.
function M.preload(filepaths, token)
  if not dot.path.is_git_repo() or (token and token:is_cancelled()) then
    return stl.c.Future.resolve(nil)
  end
  local owner = nil ---@type yoz.git.IgnoreCache|nil
  return jobs
    .run(function()
      owner = current_cache()
      return owner:start(filepaths)
    end, token)
    :then_(function(report)
      if owner ~= cache or workspace ~= dot.path.workspace() then
        return
      end
      if report.warning then
        stl.reporter.warn({
          from = __module_name__,
          subject = "preload",
          message = "git check-ignore failed",
          details = report.warning,
        })
      end
      if #report.changed > 0 then
        -- Events may repeat after native cache invalidation; they are not state snapshots.
        M.o_refreshed:next(report.changed, { force = true })
      end
    end, function(err)
      if err == "Operation cancelled" then
        return
      end
      stl.reporter.warn({ from = __module_name__, subject = "preload", message = tostring(err) })
      error(err, 0)
    end)
end

return M
