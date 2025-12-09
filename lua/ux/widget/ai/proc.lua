local config = require("ux.widget.ai.config")

---@class ux.widget.ai.proc
local M = {}

local have_ps = vim.fn.has("win32") == 0 and vim.fn.executable("ps") == 1

---@class ux.widget.ai.IProcs
---@field protected _procs              table<integer, ux.widget.ai.IProc>
---@field protected _children           table<integer, integer[]>
local Procs = {}
Procs.__index = Procs

---@return ux.widget.ai.IProcs
function Procs.new()
  local self = setmetatable({ _procs = {}, _children = {} }, Procs)
  self:__refresh__()
  return self
end

---@param pid                           integer
---@return ux.widget.ai.IProc|nil
function Procs:get(pid)
  return self._procs[pid]
end

---@param pid                           integer
---@param callback                      fun(proc: ux.widget.ai.IProc): boolean|nil
---@return nil
function Procs:walk(pid, callback)
  local queue = { pid }
  while #queue > 0 do
    local current = table.remove(queue, 1)
    local proc = self:get(current)
    if proc and callback(proc) then
      return
    end
    local children = self._children[current]
    if children then
      for _, child_pid in ipairs(children) do
        queue[#queue + 1] = child_pid
      end
    end
  end
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function Procs:__refresh__()
  self._procs = {}
  self._children = {}

  if not have_ps then
    return
  end

  local cmd = { "ps" }
  local user = vim.env.USER or ""
  if user ~= "" then
    vim.list_extend(cmd, { "-u", user })
  end
  vim.list_extend(cmd, { "-ww", "-o", "pid,ppid,args" })

  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    return
  end

  local lines = vim.split(result.stdout or "", "\n", { trimempty = true })
  for i = 2, #lines do
    local pid_str, ppid_str, args = lines[i]:match("^%s*(%d+)%s+(%d+)%s+(.*)$")
    if pid_str and ppid_str and args then
      local pid = tonumber(pid_str)
      local ppid = tonumber(ppid_str)
      if pid and ppid then
        self._procs[pid] = { pid = pid, ppid = ppid, cmd = args }
        self._children[ppid] = self._children[ppid] or {}
        self._children[ppid][#self._children[ppid] + 1] = pid
      end
    end
  end
end

----------------------------------------------------------------------------------------------------

M.Procs = Procs

---@param proc                          ux.widget.ai.IProc
---@param agent                         ux.widget.ai.AgentName
---@return boolean
function M.is_agent(proc, agent)
  local tool_config = config.tools[agent]
  if not tool_config then
    return false
  end

  if proc.cmd:find("mason/bin/copilot%-language%-server") then
    return false
  end

  local re = vim.regex(tool_config.proc_pattern)
  return re:match_str(proc.cmd) ~= nil
end

---@param procs                         ux.widget.ai.IProcs
---@param pid                           integer
---@param agent                         ux.widget.ai.AgentName
---@return boolean
function M.is_running_agent(procs, pid, agent)
  local found = false
  procs:walk(pid, function(proc)
    if M.is_agent(proc, agent) then
      found = true
      return true
    end
    return false
  end)
  return found
end

---@param procs                         ux.widget.ai.IProcs
---@param pid                           integer
---@return ux.widget.ai.AgentName|nil
function M.detect_agent(procs, pid)
  local detected = nil ---@type ux.widget.ai.AgentName|nil
  procs:walk(pid, function(proc)
    for _, agent in ipairs(config.agents) do
      if M.is_agent(proc, agent) then
        detected = agent
        return true
      end
    end
    return false
  end)
  return detected
end

return M
