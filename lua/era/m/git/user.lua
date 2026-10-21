---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.user" ---@type string

---The workspace's Git identity, which blame compares with commit authors.
---@class era.m.git.user
local M = {}

local name = nil ---@type string|nil
local email = nil ---@type string|nil

---@return nil
function M.refresh()
  if not dot.path.is_git_repo() then
    return
  end

  local workspace = dot.path.workspace() ---@type string
  stl.git.exec.exec({ "config", "user.name" }, { cwd = workspace }):finally(function(resolved, result)
    if resolved and result and result.lines and #result.lines > 0 then
      name = result.lines[1]
    end
  end)
  stl.git.exec.exec({ "config", "user.email" }, { cwd = workspace }):finally(function(resolved, result)
    if resolved and result and result.lines and #result.lines > 0 then
      email = result.lines[1]
    end
  end)
end

---@return string|nil
function M.name()
  return name
end

---@return string|nil
function M.email()
  return email
end

return M
